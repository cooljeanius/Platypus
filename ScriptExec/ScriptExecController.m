/*
    Copyright (c) 2003-2020, Sveinbjorn Thordarson <sveinbjorn@sveinbjorn.org>
    All rights reserved.

    Redistribution and use in source and binary forms, with or without modification,
    are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice, this
    list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright notice, this
    list of conditions and the following disclaimer in the documentation and/or other
    materials provided with the distribution.

    3. Neither the name of the copyright holder nor the names of its contributors may
    be used to endorse or promote products derived from this software without specific
    prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
    IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
    INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
    NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
    PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
    WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/

/* This is the source code to the main controller for the binary
 bundled into Platypus-generated applications */

#import <Security/Authorization.h>
#import <WebKit/WebKit.h>
#import <sys/stat.h>

#import "Common.h"
#import "NSColor+HexTools.h"
#import "STPrivilegedTask.h"
#import "STDragWebView.h"
#import "ScriptExecController.h"
#import "Alerts.h"
#import "ScriptExecJob.h"

#ifdef DEBUG
    #import "NSTask+Description.h"
#endif

#ifdef PLATYPUS_HEAD
-(id)init
{
    if (self = [super init]) 
    {
        task = NULL;
        privilegedTask = NULL;
        
        readHandle = NULL;
        arguments = [[NSMutableArray alloc] initWithCapacity: ARG_MAX];
        textEncoding = DEFAULT_OUTPUT_TXT_ENCODING;
        isTaskRunning = NO;
        outputEmpty = YES;
        jobQueue = [[NSMutableArray alloc] initWithCapacity: PLATYPUS_MAX_QUEUE_JOBS];
        
        statusItem = NULL;
        statusItemTitle = NULL;
        statusItemIcon = NULL;
        statusItemMenu = NULL;
    }
    return self;
}
#else
@interface ScriptExecController()
{
    // Progress bar
    IBOutlet NSWindow *progressBarWindow;
    IBOutlet NSButton *progressBarCancelButton;
    IBOutlet NSTextField *progressBarMessageTextField;
    IBOutlet NSProgressIndicator *progressBarIndicator;
    IBOutlet NSTextView *progressBarTextView;
    IBOutlet NSButton *progressBarDetailsTriangle;
    IBOutlet NSTextField *progressBarDetailsLabel;
    
    // Text Window
    IBOutlet NSWindow *textWindow;
    IBOutlet NSButton *textWindowCancelButton;
    IBOutlet NSTextView *textWindowTextView;
    IBOutlet NSProgressIndicator *textWindowProgressIndicator;
    IBOutlet NSTextField *textWindowMessageTextField;
    
    // Web View
    IBOutlet NSWindow *webViewWindow;
    IBOutlet NSButton *webViewCancelButton;
    IBOutlet WebView *webView;
    IBOutlet NSProgressIndicator *webViewProgressIndicator;
    IBOutlet NSTextField *webViewMessageTextField;
    
    // Status Item Menu
    NSStatusItem *statusItem;
    NSMenu *statusItemMenu;
    
    // Droplet
    IBOutlet NSWindow *dropletWindow;
    IBOutlet NSBox *dropletBox;
    IBOutlet NSProgressIndicator *dropletProgressIndicator;
    IBOutlet NSTextField *dropletMessageTextField;
    IBOutlet NSTextField *dropletDropFilesLabel;
    IBOutlet NSView *dropletShaderView;
    
    // Menu items
    IBOutlet NSMenuItem *hideMenuItem;
    IBOutlet NSMenuItem *quitMenuItem;
    IBOutlet NSMenuItem *aboutMenuItem;
    IBOutlet NSMenuItem *openRecentMenuItem;
    IBOutlet NSMenu *windowMenu;
    IBOutlet NSMenu *fileMenu;
    IBOutlet NSMenu *viewMenu;
    
    NSTextView *outputTextView;
    
    NSTask *task;
    STPrivilegedTask *privilegedTask;
        
    NSPipe *inputPipe;
    NSFileHandle *inputWriteFileHandle;
    NSPipe *outputPipe;
    NSFileHandle *outputReadFileHandle;
    
    NSMutableArray <NSString *> *arguments;
    NSArray <NSString *> *commandLineArguments;
    NSArray <NSString *> *interpreterArgs;
    NSArray <NSString *> *scriptArgs;
    NSString *stdinString;
    
    NSString *interpreterPath;
    NSString *scriptPath;
    NSString *appName;
    
    NSFont *textFont;
    NSColor *textForegroundColor;
    NSColor *textBackgroundColor;
    
    PlatypusExecStyle execStyle;
    PlatypusInterfaceType interfaceType;
    BOOL isDroppable;
    BOOL remainRunning;
    BOOL acceptsFiles;
    BOOL acceptsText;
    BOOL promptForFileOnLaunch;
    BOOL statusItemUsesSystemFont;
    BOOL statusItemIconIsTemplate;
    BOOL runInBackground;
    BOOL isService;
    
    NSArray <NSString *> *droppableSuffixes;
    NSArray <NSString *> *droppableUniformTypes;
    BOOL acceptAnyDroppedItem;
    BOOL acceptDroppedFolders;
    
    NSString *statusItemTitle;
    NSImage *statusItemImage;
    
    BOOL isTaskRunning;
    BOOL outputEmpty;
    BOOL hasTaskRun;
    BOOL hasFinishedLaunching;
    
    NSString *scriptText;
    NSString *remnants;
    
    NSMutableArray <ScriptExecJob *> *jobQueue;
}
@end

static const NSInteger detailsHeight = 224;

@implementation ScriptExecController

- (instancetype)init {
    self = [super init];
    if (self) {
        arguments = [NSMutableArray array];
        outputEmpty = YES;
        jobQueue = [NSMutableArray array];
    }
    return self;
}
#endif

#ifdef PLATYPUS_HEAD
-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
    // these are explicitly alloc'd in the program
    if (arguments != NULL)          { [arguments release]; }
    if (droppableSuffixes != NULL)  { [droppableSuffixes release];}
    if (droppableFileTypes != NULL) { [droppableFileTypes release];}
    if (interpreterArgs != NULL)    { [interpreterArgs release]; }
    if (scriptArgs != NULL)         { [scriptArgs release]; }
    if (statusItemIcon != NULL)     { [statusItemIcon release]; }
    if (script != NULL)             { [script release]; }
    if (statusItem != NULL)         { [statusItem release]; }
    if (statusItemMenu != NULL)     { [statusItemMenu release]; }
    [jobQueue release];
    [super dealloc];
}

#pragma mark -

-(void)awakeFromNib
{
    // load settings from AppSettings.plist in app bundle
    [self loadSettings];
    
    // prepare UI
    [self initialiseInterface];
    
    // we listen to different kind of notification depending on whether we're running
    // an NSTask or an STPrivilegedTask
    NSString *notificationName = (execStyle == PLATYPUS_PRIVILEGED_EXECUTION) ? STPrivilegedTaskDidTerminateNotification : NSTaskDidTerminateNotification;
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(taskFinished:)
                                                 name: notificationName
                                               object: NULL];
}

#pragma mark - App Settings

/**************************************************
 
 Load configuration file AppSettings.plist from 
 application bundle, sanitize it, prepare it
 
 **************************************************/

-(void)loadSettings
{
    int                i = 0;
    NSBundle        *appBundle = [NSBundle mainBundle];
    NSFileManager   *fmgr = FILEMGR;
    NSDictionary    *appSettingsPlist;
    
    //make sure all the config files are present -- if not, we quit
    if (![fmgr fileExistsAtPath: [appBundle pathForResource:@"AppSettings.plist" ofType:nil]])
        [self fatalAlert: @"Corrupt app bundle" subText: @"AppSettings.plist missing from the application bundle."];
    
    // get app name
    // first, try to get CFBundleDisplayName from Info.plist
    NSDictionary *infoPlist = [appBundle infoDictionary];
    if ([infoPlist objectForKey: @"CFBundleDisplayName"] != nil)
        appName = [[NSString alloc] initWithString: [infoPlist objectForKey: @"CFBundleDisplayName"]];
    else // if that doesn't work, use name of executable file
        appName = [[[appBundle executablePath] lastPathComponent] retain];
    
    //get dictionary with app settings
    appSettingsPlist = [NSDictionary dictionaryWithContentsOfFile: [appBundle pathForResource:@"AppSettings.plist" ofType:nil]];
    if (appSettingsPlist == NULL)
        [self fatalAlert: @"Corrupt app settings" subText: @"AppSettings.plist is corrupt."]; 
    
    //determine output type
    NSString *outputTypeStr = [appSettingsPlist objectForKey:@"OutputType"];
    if ([outputTypeStr isEqualToString: @"Progress Bar"])
        outputType = PLATYPUS_PROGRESSBAR_OUTPUT;
    else if ([outputTypeStr isEqualToString: @"Text Window"])
        outputType = PLATYPUS_TEXTWINDOW_OUTPUT;
    else if ([outputTypeStr isEqualToString: @"Web View"])
        outputType = PLATYPUS_WEBVIEW_OUTPUT;
    else if ([outputTypeStr isEqualToString: @"Status Menu"])
        outputType = PLATYPUS_STATUSMENU_OUTPUT;
    else if ([outputTypeStr isEqualToString: @"Droplet"])
        outputType = PLATYPUS_DROPLET_OUTPUT;
    else if ([outputTypeStr isEqualToString: @"None"])
        outputType = PLATYPUS_NONE_OUTPUT;
    else
        [self fatalAlert: @"Corrupt app settings" subText: @"Invalid Output Mode."];
    
    // we need some additional info from AppSettings.plist if we are presenting textual output
    if (outputType == PLATYPUS_PROGRESSBAR_OUTPUT || 
        outputType == PLATYPUS_TEXTWINDOW_OUTPUT ||
        outputType == PLATYPUS_STATUSMENU_OUTPUT)
    {
        //make sure all this data is sane, revert to defaults if not
        
        // font and size
        if ([appSettingsPlist objectForKey:@"TextFont"] && [appSettingsPlist objectForKey:@"TextSize"])
            textFont = [NSFont fontWithName: [appSettingsPlist objectForKey:@"TextFont"] size: [[appSettingsPlist objectForKey:@"TextSize"] floatValue]];
        if (!textFont)
            textFont = [NSFont fontWithName: DEFAULT_OUTPUT_FONT size: DEFAULT_OUTPUT_FONTSIZE];
        
        // foreground
        if ([appSettingsPlist objectForKey:@"TextForeground"])
            textForeground = [NSColor colorFromHex: [appSettingsPlist objectForKey:@"TextForeground"]];
        if (!textForeground)
            textForeground = [NSColor colorFromHex: DEFAULT_OUTPUT_FG_COLOR];
        
        // background
        if ([appSettingsPlist objectForKey:@"TextBackground"] != NULL)
            textBackground    = [NSColor colorFromHex: [appSettingsPlist objectForKey:@"TextBackground"]];
        if (!textBackground)
            textBackground = [NSColor colorFromHex: DEFAULT_OUTPUT_BG_COLOR];
        
        // encoding
        if ([appSettingsPlist objectForKey:@"TextEncoding"])
            textEncoding = (int)[[appSettingsPlist objectForKey:@"TextEncoding"] intValue];
        else
            textEncoding = DEFAULT_OUTPUT_TXT_ENCODING;            
        
        [textFont retain];
        [textForeground retain];
        [textBackground retain];
    }
    
    // likewise, status menu output has some additional parameters
    if (outputType == PLATYPUS_STATUSMENU_OUTPUT)
    {
        // we load text label if status menu is not only an icon
        if ([[appSettingsPlist objectForKey: @"StatusItemDisplayType"] isEqualToString: @"Text"] ||
            [[appSettingsPlist objectForKey: @"StatusItemDisplayType"] isEqualToString: @"Icon and Text"])
        {
            statusItemTitle = [[appSettingsPlist objectForKey: @"StatusItemTitle"] retain];
            if (statusItemTitle == NULL)
                [self fatalAlert: @"Error getting title" subText: @"Failed to get Status Item title."];
        }
        else
            statusItemTitle = NULL;
        
        // we load icon if status menu is not only a text label
        if ([[appSettingsPlist objectForKey: @"StatusItemDisplayType"] isEqualToString: @"Icon"] ||
            [[appSettingsPlist objectForKey: @"StatusItemDisplayType"] isEqualToString: @"Icon and Text"])
        {
            statusItemIcon = [[NSImage alloc] initWithData: [appSettingsPlist objectForKey: @"StatusItemIcon"]];
            if (statusItemIcon == NULL)
                [self fatalAlert: @"Error loading icon" subText: @"Failed to load Status Item icon."];
        }
        else
            statusItemIcon = NULL;
        
        if (statusItemIcon == NULL && statusItemTitle == NULL)
            statusItemTitle = @"Title";
    }
    
    //load these vars from plist
    interpreterArgs     = [[NSArray arrayWithArray: [appSettingsPlist objectForKey:@"InterpreterArgs"]] retain];
    scriptArgs          = [[NSArray arrayWithArray: [appSettingsPlist objectForKey:@"ScriptArgs"]] retain];
    execStyle           = [[appSettingsPlist objectForKey:@"RequiresAdminPrivileges"] boolValue];
    remainRunning       = [[appSettingsPlist objectForKey:@"RemainRunningAfterCompletion"] boolValue];
    secureScript        = [[appSettingsPlist objectForKey: @"Secure"] boolValue];
    isDroppable         = [[appSettingsPlist objectForKey: @"Droppable"] boolValue];
    promptForFileOnLaunch = [[appSettingsPlist objectForKey: @"PromptForFileOnLaunch"] boolValue];
    
    // never privileged execution or droppable w. status menu
    if (outputType == PLATYPUS_STATUSMENU_OUTPUT) 
    {
        remainRunning = YES;
        execStyle = PLATYPUS_NORMAL_EXECUTION;
        isDroppable = NO;
    }
    
    // load settings for drop acceptance, default is to accept files and not text snippets
    acceptsFiles = ([appSettingsPlist objectForKey: @"AcceptsFiles"] != nil) ? [[appSettingsPlist objectForKey: @"AcceptsFiles"] boolValue] : YES;
    acceptsText = ([appSettingsPlist objectForKey: @"AcceptsText"] != nil) ? [[appSettingsPlist objectForKey: @"AcceptsText"] boolValue] : NO;
    
    if (!acceptsFiles && !acceptsText) // equivalent to not being droppable
        isDroppable = FALSE;
    
    // initialize this to NO, then check the droppableSuffixes for 'fold'
    acceptDroppedFolders = NO;
    // initialize this to NO, then check the droppableSuffixes for *, and droppableFileTypes for ****
    acceptAnyDroppedItem = NO; 
    
    // if app is droppable, the AppSettings.plist contains list of accepted file types / suffixes
    // we use them later as a criterion for in-code drop acceptance 
    if (isDroppable && acceptsFiles)
    {    
        // get list of accepted suffixes
        if([appSettingsPlist objectForKey: @"DropSuffixes"])
            droppableSuffixes = [[NSArray alloc] initWithArray:  [appSettingsPlist objectForKey:@"DropSuffixes"]];
        else
            droppableSuffixes = [[NSArray alloc] initWithArray: [NSArray array]];
        [droppableSuffixes retain];
        
        // get list of accepted file types
        if([appSettingsPlist objectForKey:@"DropTypes"])
            droppableFileTypes = [[NSArray alloc] initWithArray:  [appSettingsPlist objectForKey:@"DropTypes"]];
        else
            droppableFileTypes = [[NSArray alloc] initWithArray: [NSArray array]];
        [droppableFileTypes retain];
        
        // see if we accept any dropped item, * suffix or **** file type makes it so
        for (i = 0; i < [droppableSuffixes count]; i++)
            if ([[droppableSuffixes objectAtIndex:i] isEqualToString:@"*"]) //* suffix
                acceptAnyDroppedItem = YES;
        
        for (i = 0; i < [droppableFileTypes count]; i++)
            if([[droppableFileTypes objectAtIndex:i] isEqualToString:@"****"])//**** filetype
                acceptAnyDroppedItem = YES;
        
        // see if we acccept dropped folders, requires filetype 'fold'
        for(i = 0; i < [droppableFileTypes count]; i++)
            if([[droppableFileTypes objectAtIndex: i] isEqualToString: @"fold"])
                acceptDroppedFolders = YES;
    }
    
    //get interpreter
    interpreter = [[NSString stringWithString: [appSettingsPlist objectForKey:@"ScriptInterpreter"]] retain];
    if (![fmgr fileExistsAtPath: interpreter])
        [self fatalAlert: @"Missing interpreter" subText: [NSString stringWithFormat: @"This application could not run because the interpreter '%@' does not exist on this system.", interpreter]];
    
    //if the script is not "secure" then we need a script file, otherwise we need data in AppSettings.plist
    if ((!secureScript && ![fmgr fileExistsAtPath: [appBundle pathForResource:@"script" ofType: NULL]]) || (secureScript && [appSettingsPlist objectForKey:@"TextSettings"] == NULL))
        [self fatalAlert: @"Corrupt app bundle" subText: @"Script missing from application bundle."];
    
    //get path to script within app bundle
    if (!secureScript)
    {
        scriptPath = [[NSString stringWithString: [appBundle pathForResource:@"script" ofType:nil]] retain];
        
        // make sure we can read the script file
        if (![fmgr isReadableFileAtPath: scriptPath]) // if unreadable
            chmod([scriptPath cStringUsingEncoding: NSUTF8StringEncoding], S_IRWXU | S_IRWXG | S_IROTH); // chmod 774
        if (![fmgr isReadableFileAtPath: scriptPath]) // if still unreadable
            [self fatalAlert: @"Corrupt app bundle" subText: @"Script file is not readable."];
            
    }
    //if we have a "secure" script, there is no path to get, we write script to temp location on execution
    else
    {
        NSData *b_str = [NSKeyedUnarchiver unarchiveObjectWithData: [appSettingsPlist objectForKey:@"TextSettings"]];
        if (b_str == NULL)
            [self fatalAlert: @"Corrupt app bundle" subText: @"Script missing from application bundle."];
        
        // we create string with the script based on the decoded data
        script = [[NSString alloc] initWithData: b_str encoding: textEncoding];
    }
}

#pragma mark - App Delegate handlers

-(void)applicationDidFinishLaunching: (NSNotification *)aNotification
{    
    [NSApp setServicesProvider:self]; // register as text handling service
    
    // status menu apps just run when item is clicked
    // for all others, we run the script once app is up and running
    if (outputType != PLATYPUS_STATUSMENU_OUTPUT && !promptForFileOnLaunch)
        [self executeScript];
    else if (promptForFileOnLaunch && isDroppable)
        [self openFiles: self];
}

-(void)application: (NSApplication *)theApplication openFiles: (NSArray *)filenames
{
    // add the dropped files as a job for processing
    int ret = [self addDroppedFilesJob: filenames];
    
    // if no other job is running, we execute
    if (!isTaskRunning && ret)
        [self executeScript];
}

-(NSApplicationTerminateReply)applicationShouldTerminate: (NSApplication *)sender
{    
    // again, make absolutely sure we don't leave the clear-text script in temp directory
    if (secureScript && [FILEMGR fileExistsAtPath: scriptPath])
        [FILEMGR removeItemAtPath: scriptPath error: nil];
        
    //terminate task
    if (task != NULL)
    {
        if ([task isRunning])
            [task terminate];
        [task release];
    }
    
    //terminate privileged task
    if (privilegedTask != NULL)
    {
        if ([privilegedTask isRunning])
            [privilegedTask terminate];
        [privilegedTask release];
    }
    
    // hide status item, if on
    if (statusItem)
        [[NSStatusBar systemStatusBar] removeStatusItem: statusItem];

    // clean out the job queue since we're quitting
    [jobQueue removeAllObjects];
    
    return YES;
}

#pragma mark - Interface manipulation
#else
- (void)awakeFromNib {
    // Load settings from AppSettings.plist in app bundle
    [self loadAppSettings];
    
    // Prepare UI
    [self initialiseInterface];
    
    // Listen for terminate notification
    NSString *notificationName = NSTaskDidTerminateNotification;
    if (execStyle == PlatypusExecStyle_Authenticated) {
        notificationName = STPrivilegedTaskDidTerminateNotification;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(taskFinished:)
                                                 name:notificationName
                                               object:nil];

    // Listen for Open URL events
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self
                                                       andSelector:@selector(getUrl:withReplyEvent:)
                                                     forEventClass:kInternetEventClass
                                                        andEventID:kAEGetURL];
    
    // Register as text handling service
    if (isService) {
        [NSApp setServicesProvider:self];
        NSMutableArray *sendTypes = [NSMutableArray array];
        if (acceptsFiles) {
            [sendTypes addObject:NSFilenamesPboardType];
        }
        if (acceptsText) {
            [sendTypes addObject:NSStringPboardType];
        }
        [NSApp registerServicesMenuSendTypes:sendTypes returnTypes:@[]];
    }
    
    // User Notification Center
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
}

#pragma mark - App Settings

// Load configuration from AppSettings.plist and Info.plist, sanitize values, etc.
- (void)loadAppSettings {
    // Application bundle
    NSBundle *bundle = [NSBundle mainBundle];
    
    // Try to get app name from Info.plist
    NSDictionary *infoPlist = [bundle infoDictionary];
    if (infoPlist[@"CFBundleName"]) {
        appName = infoPlist[@"CFBundleName"];
    } else {
        // If that doesn't work, use name of executable file
        appName = [[bundle executablePath] lastPathComponent];
    }
    
    runInBackground = [infoPlist[@"LSUIElement"] boolValue];
    isService = (infoPlist[@"NSServices"] != nil);
    
    // Check if script file exists
    scriptPath = [bundle pathForResource:@"script" ofType:nil];
    if ([FILEMGR fileExistsAtPath:scriptPath] == NO) {
        [Alerts fatalAlert:@"Corrupt app bundle"
                   subText:@"Script missing from application bundle."];
    }
    
    // Make sure script is executable and readable
    NSNumber *permissions = [NSNumber numberWithUnsignedLong:493];
    NSDictionary *attributes = @{ NSFilePosixPermissions:permissions };
    [FILEMGR setAttributes:attributes ofItemAtPath:scriptPath error:nil];
    if ([FILEMGR isReadableFileAtPath:scriptPath] == NO || [FILEMGR isExecutableFileAtPath:scriptPath] == NO) {
        [Alerts fatalAlert:@"Corrupt app bundle"
                   subText:@"Script file is not readable/executable."];
    }
    
    // Make sure there's an AppSettings.plist file
    NSString *appSettingsPath = [bundle pathForResource:@"AppSettings.plist" ofType:nil];
    if (![FILEMGR fileExistsAtPath:appSettingsPath]) {
        [Alerts fatalAlert:@"Corrupt app bundle"
                   subText:@"AppSettings.plist not found in application bundle."];
    }
    
    // Load settings from property list
    NSDictionary *appSettings = [NSDictionary dictionaryWithContentsOfFile:appSettingsPath];
    if (appSettings == nil) {
        [Alerts fatalAlert:@"Corrupt app settings"
                   subText:@"Unable to read AppSettings.plist."];
    }
    
    // Validate interpreter specified in settings
    interpreterPath = appSettings[AppSpecKey_InterpreterPath];
    if ([FILEMGR fileExistsAtPath:interpreterPath] == NO) {
        [Alerts fatalAlert:@"Missing interpreter"
             subTextFormat:@"The interpreter '%@' could not be found.", interpreterPath];
    }
    
    // Determine interface type
    NSString *interfaceTypeStr = appSettings[AppSpecKey_InterfaceType];
    if (IsValidInterfaceTypeString(interfaceTypeStr) == NO) {
        [Alerts fatalAlert:@"Corrupt app settings"
             subTextFormat:@"Invalid Interface Type: '%@'.", interfaceTypeStr];
    }
    interfaceType = InterfaceTypeForString(interfaceTypeStr);
    
    // Text styling - we ignore those values unless output mode has a text view
    if (IsTextStyledInterfaceType(interfaceType)) {
    
        // Font and size
        NSNumber *userFontSizeNum = [DEFAULTS objectForKey:ScriptExecDefaultsKey_UserFontSize];
        CGFloat fontSize = userFontSizeNum ? [userFontSizeNum floatValue] : [appSettings[AppSpecKey_TextSize] floatValue];
        fontSize = fontSize != 0 ? fontSize : DEFAULT_TEXT_FONT_SIZE;
        
        if (appSettings[AppSpecKey_TextFont]) {
            textFont = [NSFont fontWithName:appSettings[AppSpecKey_TextFont] size:fontSize];
        }
        if (textFont == nil) {
            textFont = [NSFont fontWithName:DEFAULT_TEXT_FONT_NAME size:DEFAULT_TEXT_FONT_SIZE];
        }
        
        // Foreground color
        if (appSettings[AppSpecKey_TextColor]) {
            textForegroundColor = [NSColor colorFromHexString:appSettings[AppSpecKey_TextColor]];
        }
        if (textForegroundColor == nil) {
            textForegroundColor = [NSColor colorFromHexString:DEFAULT_TEXT_FG_COLOR];
        }
        
        // Background color
        if (appSettings[AppSpecKey_TextBackgroundColor]) {
            textBackgroundColor = [NSColor colorFromHexString:appSettings[AppSpecKey_TextBackgroundColor]];
        }
        if (textBackgroundColor == nil) {
            textBackgroundColor = [NSColor colorFromHexString:DEFAULT_TEXT_BG_COLOR];
        }
    }
    
    // Status menu interface has some additional settings
    if (interfaceType == PlatypusInterfaceType_StatusMenu) {
        NSString *statusItemDisplayType = appSettings[AppSpecKey_StatusItemDisplayType];

        if ([statusItemDisplayType isEqualToString:PLATYPUS_STATUSITEM_DISPLAY_TYPE_TEXT]) {
            statusItemTitle = [appSettings[AppSpecKey_StatusItemTitle] copy];
            if (statusItemTitle == nil) {
                [Alerts alert:@"Error getting title" subText:@"Failed to get Status Item title."];
            }
        }
        else if ([statusItemDisplayType isEqualToString:PLATYPUS_STATUSITEM_DISPLAY_TYPE_ICON]) {
            statusItemImage = [[NSImage alloc] initWithData:appSettings[AppSpecKey_StatusItemIcon]];
            if (statusItemImage == nil) {
                [Alerts alert:@"Error loading icon" subText:@"Failed to load Status Item icon."];
            }
        }
        
        // Fallback if no title or icon is specified
        if (statusItemImage == nil && statusItemTitle == nil) {
            statusItemTitle = DEFAULT_STATUS_ITEM_TITLE;
        }
        
        statusItemUsesSystemFont = [appSettings[AppSpecKey_StatusItemUseSysfont] boolValue];
        statusItemIconIsTemplate = [appSettings[AppSpecKey_StatusItemIconIsTemplate] boolValue];
    }
    
    interpreterArgs = [appSettings[AppSpecKey_InterpreterArgs] copy];
    scriptArgs = [appSettings[AppSpecKey_ScriptArgs] copy];
    execStyle = (PlatypusExecStyle)[appSettings[AppSpecKey_Authenticate] intValue];
    remainRunning = [appSettings[AppSpecKey_RemainRunning] boolValue];
    isDroppable = NO;
    promptForFileOnLaunch = [appSettings[AppSpecKey_PromptForFile] boolValue];
    
    // Read and store command line arguments to the ScriptExec application binary
    commandLineArguments = [self readCommandLineArguments];
    
    // Load settings for drop acceptance
    acceptsFiles = appSettings[AppSpecKey_AcceptFiles] ? [appSettings[AppSpecKey_AcceptFiles] boolValue] : NO;
    acceptsText = appSettings[AppSpecKey_AcceptText] ? [appSettings[AppSpecKey_AcceptText] boolValue] : NO;
    
    if (acceptsFiles || acceptsText) {
        isDroppable = TRUE;
    }

    acceptAnyDroppedItem = NO;
    acceptDroppedFolders = NO;

    // If app is droppable, the AppSettings.plist contains list of accepted file types / suffixes
    // We use them later as a criterion for drop acceptance
    if (acceptsFiles) {
        // Get list of accepted suffixes
        droppableSuffixes = [NSArray array];
        droppableUniformTypes = [NSArray array];

        if (appSettings[AppSpecKey_Suffixes]) {
            droppableSuffixes = [appSettings[AppSpecKey_Suffixes] copy];
        }
        if (appSettings[AppSpecKey_Utis]) {
            droppableUniformTypes = [appSettings[AppSpecKey_Utis] copy];
        }
        if ([droppableSuffixes containsObject:@"*"] || [droppableUniformTypes containsObject:@"public.data"]) {
            acceptAnyDroppedItem = YES;
        }
        else if ([droppableSuffixes containsObject:@"fold"] || [droppableUniformTypes containsObject:(NSString *)kUTTypeFolder]) {
            acceptDroppedFolders = YES;
        }
    }
    
    // We never have privileged execution or droppable with status menu apps
    if (interfaceType == PlatypusInterfaceType_StatusMenu) {
        remainRunning = YES;
        execStyle = PlatypusExecStyle_Normal;
        isDroppable = NO;
    }
}

// Read and filter command line arguments passed to the app binary
- (NSArray *)readCommandLineArguments {
    NSMutableArray *processArgs = [[[NSProcessInfo processInfo] arguments] mutableCopy];
    NSMutableArray *cltArgs = [NSMutableArray new];
    
    if ([processArgs count] > 1) {
        // The first argument is always the path to the binary, so we remove that
        [processArgs removeObjectAtIndex:0];
        BOOL lastWasDocRevFlag = NO;
        
        // Filter out remaining arguments that we don't want to pass on
        for (NSString *arg in processArgs) {
            // On older versions of Mac OS X, apps opened from the Finder are passed
            // a Carbon Process Serial Number argument of the form -psn_0_*******
            // We should ignore these
            if ([arg hasPrefix:@"-psn_"]) {
                continue;
            }
            // Hack to remove Xcode CLI flags -NSDocumentRevisionsDebugMode YES.
            // Just here to make debugging ScriptExec easier.
            if ([arg isEqualToString:@"YES"] && lastWasDocRevFlag) {
                continue;
            }
            if ([arg isEqualToString:@"-NSDocumentRevisionsDebugMode"]) {
                lastWasDocRevFlag = YES;
                continue;
            } else {
                lastWasDocRevFlag = NO;
            }
            
            [cltArgs addObject:arg];
        }
    }
    return [cltArgs copy]; // Return immutable copy
}

#pragma mark - App Delegate handlers

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    PLog(@"Application did finish launching");
    hasFinishedLaunching = YES;
    
    // Status menu apps just run when item is clicked
    // For all others, we run the script once app has launched
    if (interfaceType == PlatypusInterfaceType_StatusMenu) {
        return;
    }
    
    if (promptForFileOnLaunch && acceptsFiles && [jobQueue count] == 0) {
        [self openFiles:self];
    } else {
        [self executeScript];
    }
}
#endif

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

#ifdef PLATYPUS_HEAD
-(void)initialiseInterface
{
    //put application name into the relevant menu items
    [quitMenuItem setTitle: [NSString stringWithFormat: @"Quit %@", appName]];
    [aboutMenuItem setTitle: [NSString stringWithFormat: @"About %@", appName]];
    [hideMenuItem setTitle: [NSString stringWithFormat: @"Hide %@", appName]];
    
    // script output will be dumped in outputTextView, by default this is the Text Window text view
    outputTextView = textOutputTextView;
    
    // force us to be front process if we run in background
    // This is so that apps that are set to run in the background will still have their
    // window come to the front.  It is to my knowledge the only way to make an
    // application with LSUIElement set to true come to the front on launch
    // We don't do this for applications with no user interface output
    if (outputType != PLATYPUS_NONE_OUTPUT)
    {
        ProcessSerialNumber process;
        GetCurrentProcess(&process);
        SetFrontProcess(&process);
    }
    
    //prepare controls etc. for different output types
    switch (outputType)
    {
        case PLATYPUS_NONE_OUTPUT:
        {
            // nothing to do
        }
        break;
            
        case PLATYPUS_PROGRESSBAR_OUTPUT:
        {
            if (isDroppable)
                [progressBarWindow registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil]];
            
            // add menu item for Show Details
            [[windowMenu insertItemWithTitle: @"Toggle Details" action: @selector(performClick:)  keyEquivalent:@"T" atIndex: 2] setTarget: progressBarDetailsTriangle];
            [windowMenu insertItem: [NSMenuItem separatorItem] atIndex: 2];
            
            // style the text field
            outputTextView = progressBarTextView;
            [outputTextView setFont: textFont];
            [outputTextView setTextColor: textForeground];
            [outputTextView setBackgroundColor: textBackground];
            
            // add drag instructions message if droplet
            if (isDroppable)
                [progressBarMessageTextField setStringValue: @"Drag files to process"];
            else
                [progressBarMessageTextField setStringValue: @"Running..."];
            
            [progressBarIndicator setUsesThreadedAnimation: YES];
            
            //preare window
            [progressBarWindow setTitle: appName];
            
            //center it if first time running the application
            if ([[progressBarWindow frameAutosaveName] isEqualToString: @""])
                [progressBarWindow center];
            
            // reveal it
            [progressBarWindow makeKeyAndOrderFront: self];
        }
        break;
            
        case PLATYPUS_TEXTWINDOW_OUTPUT:
        {
            if (isDroppable)
            {
                [textOutputWindow registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil]];
                [textOutputMessageTextField setStringValue: @"Drag files on window to process them"];
            }
            
            // style the text field
            [outputTextView setFont: textFont];
            [outputTextView setTextColor: textForeground];
            [outputTextView setBackgroundColor: textBackground];                
            
            [textOutputProgressIndicator setUsesThreadedAnimation: YES];
            
            // prepare window
            [textOutputWindow setTitle: appName];
            if ([[textOutputWindow frameAutosaveName] isEqualToString: @""])
                [textOutputWindow center];
            [textOutputWindow makeKeyAndOrderFront: self];
        }
        break;
            
        case PLATYPUS_WEBVIEW_OUTPUT:
        {
            if (isDroppable)
            {
                [webOutputWindow registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil]];
                [webOutputWebView registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil]];
                [webOutputMessageTextField setStringValue: @"Drag files on window to process them"];
            }
            
            [webOutputProgressIndicator setUsesThreadedAnimation: YES];
            
            // prepare window
            [webOutputWindow setTitle: appName];
            [webOutputWindow center];
            if ([[webOutputWindow frameAutosaveName] isEqualToString: @""])
                [webOutputWindow center];
            [webOutputWindow makeKeyAndOrderFront: self];        
            
        }
        break;
            
        case PLATYPUS_STATUSMENU_OUTPUT:
        {
            // create and activate status item
            statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength: NSVariableStatusItemLength] retain];
            [statusItem setHighlightMode: YES];
            
            // set status item title and icon
            if (statusItemTitle != NULL)
                [statusItem setTitle: statusItemTitle];
            if (statusItemIcon != NULL)
                [statusItem setImage: statusItemIcon];
                        
            // create menu for our status item
            statusItemMenu = [[NSMenu alloc] initWithTitle: @""];
            [statusItemMenu setDelegate: self];
            [statusItem setMenu: statusItemMenu];
            
            //create Quit menu item
            NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle: [NSString stringWithFormat: @"Quit %@", appName] action: @selector(terminate:) keyEquivalent: @""] autorelease];
            [statusItemMenu insertItem: menuItem atIndex: 0];
            [statusItemMenu insertItem: [NSMenuItem separatorItem] atIndex: 0];
            
            // enable it
            [statusItem setEnabled: YES];
        }
        break;
            
        case PLATYPUS_DROPLET_OUTPUT:
        {            
            if (isDroppable)
                [dropletWindow registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil]];
            
            [dropletProgressIndicator setUsesThreadedAnimation: YES];
            
            // prepare window
            [dropletWindow setTitle: appName];
            if ([[dropletWindow frameAutosaveName] isEqualToString: @""])
                [dropletWindow center];
            [dropletWindow makeKeyAndOrderFront: self];
        }
        break;
    }
}
#else
- (void)application:(NSApplication *)theApplication openFiles:(NSArray *)filenames {
    PLog(@"Received openFiles event for files: %@", [filenames description]);
    
    if (hasTaskRun == FALSE && commandLineArguments != nil) {
        for (NSString *filePath in filenames) {
            if ([commandLineArguments containsObject:filePath]) {
                return;
            }
        }
    }
    
    // Add the dropped files as a job for processing
    BOOL success = [self addDroppedFilesJob:filenames];
    [NSApp replyToOpenOrPrint:success ? NSApplicationDelegateReplySuccess : NSApplicationDelegateReplyFailure];
    
    // If no other job is running, we execute
    if (success && !isTaskRunning && hasFinishedLaunching) {
        [self executeScript];
    }
}
#endif

- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *url = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    PLog(@"Received open URL event for URL %@", url);
    
    // Add URL as a job for processing
    BOOL success = [self addURLJob:url];
    
    // If no other job is running, we execute
    if (!isTaskRunning && success && hasFinishedLaunching) {
        [self executeScript];
    }
}

#ifdef PLATYPUS_HEAD
-(void)prepareInterfaceForExecution
{
    switch(outputType)
    {
        case PLATYPUS_PROGRESSBAR_OUTPUT:
        {
            [progressBarIndicator setIndeterminate: YES];
            [progressBarIndicator startAnimation: self];
            [progressBarMessageTextField setStringValue: @"Running..."];
            [outputTextView setString: @"\n"];
            [progressBarCancelButton setTitle: @"Cancel"];
            if (execStyle == PLATYPUS_PRIVILEGED_EXECUTION) { [progressBarCancelButton setEnabled: NO]; }
        }
        break;
            
        case PLATYPUS_TEXTWINDOW_OUTPUT:
        {   
            [outputTextView setString: @"\n"];
            [textOutputCancelButton setTitle: @"Cancel"];
            if (execStyle == PLATYPUS_PRIVILEGED_EXECUTION) { [textOutputCancelButton setEnabled: NO]; }
            [textOutputProgressIndicator startAnimation: self];
        }
        break;
            
        case PLATYPUS_WEBVIEW_OUTPUT:
        {
            [outputTextView setString: @"\n"];
            [webOutputCancelButton setTitle: @"Cancel"];
            if (execStyle == PLATYPUS_PRIVILEGED_EXECUTION) { [webOutputCancelButton setEnabled: NO]; }
            [webOutputProgressIndicator startAnimation: self];
        }
        break;
            
        case PLATYPUS_STATUSMENU_OUTPUT:
        {
            [outputTextView setString: @""];
        }
        break;
            
        case PLATYPUS_DROPLET_OUTPUT:
        {
            [dropletProgressIndicator setIndeterminate: YES];
            [dropletProgressIndicator startAnimation: self];
            [dropletDropFilesLabel setHidden: YES];
            [dropletMessageTextField setHidden: NO];
            [dropletMessageTextField setStringValue: @"Processing..."];
            [outputTextView setString: @"\n"];
        }
        break;
    }
}
#else
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    // Terminate task
    if (task != nil) {
        if ([task isRunning]) {
            [task terminate];
        }
        task = nil;
    }
    
    // Terminate privileged task
    if (privilegedTask != nil) {
        if ([privilegedTask isRunning]) {
            [privilegedTask terminate];
        }
        privilegedTask = nil;
    }
    
    // Hide status item
    if (statusItem) {
        [[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
    }
    
    return NSTerminateNow;
}

#pragma mark - Interface manipulation

// Set up any menu items, windows, controls at application launch
- (void)initialiseInterface {
    
    // Put application name into the relevant menu items
    [quitMenuItem setTitle:[NSString stringWithFormat:@"Quit %@", appName]];
    [aboutMenuItem setTitle:[NSString stringWithFormat:@"About %@", appName]];
    [hideMenuItem setTitle:[NSString stringWithFormat:@"Hide %@", appName]];
    
    [openRecentMenuItem setEnabled:acceptsFiles];
    if (!acceptsFiles) {
        [fileMenu removeItemAtIndex:0]; // Open
        [fileMenu removeItemAtIndex:0]; // Open Recent..
        [fileMenu removeItemAtIndex:0]; // Separator
    }
    if (!IsTextSizableInterfaceType(interfaceType)) {
        [viewMenu removeItemAtIndex:0];
        [viewMenu removeItemAtIndex:0];
        [viewMenu removeItemAtIndex:0];
    }
    
    // Script output will be dumped in outputTextView
    // By default this is the Text Window text view
    outputTextView = textWindowTextView;

    if (runInBackground == TRUE) {
        // Old Carbon way
#ifdef OLD_CARBON_WAY
        ProcessSerialNumber process;
        GetCurrentProcess(&process);
        SetFrontProcess(&process);
#endif
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    }
    
    // Prepare controls etc. for different interface types
    switch (interfaceType) {
        case PlatypusInterfaceType_None:
            // Nothing to do
            break;
            
        case PlatypusInterfaceType_ProgressBar:
        {
            if (isDroppable) {
                [progressBarWindow registerForDraggedTypes:@[NSFilenamesPboardType, NSStringPboardType]];
            }
            
            // Add menu item for Show Details
            [[windowMenu insertItemWithTitle:@"Toggle Details" action:@selector(performClick:) keyEquivalent:@"T" atIndex:2] setTarget:progressBarDetailsTriangle];
            [windowMenu insertItem:[NSMenuItem separatorItem] atIndex:2];
            
            // Style the text field
            outputTextView = progressBarTextView;
            [outputTextView setBackgroundColor:textBackgroundColor];
            [outputTextView setTextColor:textForegroundColor];
            [outputTextView setFont:textFont];
            [[outputTextView textStorage] setFont:textFont];
            
            // Add drag instructions message if droplet
            NSString *progBarMsg = isDroppable ? @"Drag files to process" : @"Running...";
            [progressBarMessageTextField setStringValue:progBarMsg];
            [progressBarIndicator setUsesThreadedAnimation:YES];
            
            // Prepare window
            [progressBarWindow setTitle:appName];
            
            if ([DEFAULTS boolForKey:ScriptExecDefaultsKey_ShowDetails]) {
                NSRect frame = [progressBarWindow frame];
                frame.origin.y += detailsHeight;
                [progressBarWindow setFrame:frame display:NO];
                [self showDetails];
            }
            
            [progressBarWindow makeKeyAndOrderFront:self];
        }
            break;
            
        case PlatypusInterfaceType_TextWindow:
        {
            if (isDroppable) {
                [textWindow registerForDraggedTypes:@[NSFilenamesPboardType, NSStringPboardType]];
            }
            
            [textWindowProgressIndicator setUsesThreadedAnimation:YES];
            [outputTextView setBackgroundColor:textBackgroundColor];
            [outputTextView setTextColor:textForegroundColor];
            [outputTextView setFont:textFont];
            [[outputTextView textStorage] setFont:textFont];
            
            // Prepare window
            [textWindow setTitle:appName];
            [textWindow makeKeyAndOrderFront:self];
        }
            break;
            
        case PlatypusInterfaceType_WebView:
        {
            if (isDroppable) {
                [webViewWindow registerForDraggedTypes:@[NSFilenamesPboardType, NSStringPboardType]];
                [webView registerForDraggedTypes:@[NSFilenamesPboardType, NSStringPboardType]];
                [webViewMessageTextField setStringValue:@"Drag files on window to process them"];
            }
            
            [webViewProgressIndicator setUsesThreadedAnimation:YES];
            
            // Prepare window
            [webViewWindow setTitle:appName];
            [webViewWindow makeKeyAndOrderFront:self];
        }
            break;
            
        case PlatypusInterfaceType_StatusMenu:
        {
            // Create and activate status item
            statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
            [statusItem setHighlightMode:YES];
            
            // Set status item title and icon
            [statusItem setTitle:statusItemTitle];
            
            NSSize statusItemSize = [statusItemImage size];
            CGFloat rel = 18/statusItemSize.height;
            NSSize finalSize = NSMakeSize(statusItemSize.width * rel, statusItemSize.height * rel);
            [statusItemImage setSize:finalSize];
            [statusItemImage setTemplate:statusItemIconIsTemplate];
            [statusItem setImage:statusItemImage];
            
            // Create menu for our status item
            statusItemMenu = [[NSMenu alloc] initWithTitle:@""];
            [statusItemMenu setDelegate:self];
            [statusItem setMenu:statusItemMenu];
            
            // Create Quit menu item
            NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Quit %@", appName] action:@selector(terminate:) keyEquivalent:@""];
            [statusItemMenu insertItem:menuItem atIndex:0];
            [statusItemMenu insertItem:[NSMenuItem separatorItem] atIndex:0];
            [statusItem setEnabled:YES];
        }
            break;
            
        case PlatypusInterfaceType_Droplet:
        {
            if (isDroppable) {
                [dropletWindow registerForDraggedTypes:@[NSFilenamesPboardType, NSStringPboardType]];
            }
            [dropletProgressIndicator setUsesThreadedAnimation:YES];
            
            // Prepare window
            [dropletWindow setTitle:appName];
            [dropletWindow makeKeyAndOrderFront:self];
        }
            break;
    }
}
#endif

// Prepare all the controls, windows, etc prior to executing script
- (void)prepareInterfaceForExecution {
    [outputTextView setString:@""];
    
    switch (interfaceType) {
        case PlatypusInterfaceType_None:
        case PlatypusInterfaceType_StatusMenu:
            break;
            
        case PlatypusInterfaceType_ProgressBar:
        {
            // Yes, yes, this is a nasty hack. But styling in NSTextViews
            // doesn't get applied when appending text unless there is already
            // some text in the view. The alternative is to make very expensive
            // calls to [textStorage setAttributes:] for all appended output,
            // which freezes up the app when lots of text is dumped by the script
            [outputTextView setString:@"\u200B"]; // zero-width space character

            [progressBarIndicator setIndeterminate:YES];
            [progressBarIndicator startAnimation:self];
            [progressBarMessageTextField setStringValue:@"Running..."];
            [progressBarCancelButton setTitle:@"Cancel"];
            if (execStyle == PlatypusExecStyle_Authenticated) {
                [progressBarCancelButton setEnabled:NO];
            }
        }
            break;
            
        case PlatypusInterfaceType_TextWindow:
        {
            // Yes, yes, this is a nasty hack. But styling in NSTextViews
            // doesn't get applied when appending text unless there is already
            // some text in the view. The alternative is to make very expensive
            // calls to [textStorage setAttributes:] for all appended output,
            // which freezes up the app when lots of text is dumped by the script
            [outputTextView setString:@"\u200B"]; // zero-width space character

            [textWindowCancelButton setTitle:@"Cancel"];
            if (execStyle == PlatypusExecStyle_Authenticated) {
                [textWindowCancelButton setEnabled:NO];
            }
            [textWindowProgressIndicator startAnimation:self];
        }
            break;
            
        case PlatypusInterfaceType_WebView:
        {
            [webViewCancelButton setTitle:@"Cancel"];
            if (execStyle == PlatypusExecStyle_Authenticated) {
                [webViewCancelButton setEnabled:NO];
            }
            [webViewProgressIndicator startAnimation:self];
        }
            break;
            
        case PlatypusInterfaceType_Droplet:
        {
            [dropletProgressIndicator setIndeterminate:YES];
            [dropletProgressIndicator startAnimation:self];
            [dropletDropFilesLabel setHidden:YES];
            [dropletMessageTextField setHidden:NO];
            [dropletMessageTextField setStringValue:@"Processing..."];
        }
            break;
            
    }
}

#ifdef PLATYPUS_HEAD
-(void)cleanupInterface
{
    switch (outputType)
    {
        case PLATYPUS_TEXTWINDOW_OUTPUT:
        {
            //update controls for text output window
            [textOutputCancelButton setTitle: @"Quit"];
            [textOutputCancelButton setEnabled: YES];
            [textOutputProgressIndicator stopAnimation: self];
        }
        break;
            
        case PLATYPUS_PROGRESSBAR_OUTPUT:
        {
            // if there are any remnants, we append them to output
            if (remnants != NULL) 
            { 
                NSTextStorage *text = [outputTextView textStorage];
                [text replaceCharactersInRange: NSMakeRange([text length], 0) withString: remnants];
                [remnants release]; 
                remnants = NULL; 
            }
            
            //update controls for progress bar output
            [progressBarIndicator stopAnimation: self];
            
            if (isDroppable)
            {
                [progressBarMessageTextField setStringValue: @"Drag files to process"];
                [progressBarIndicator setIndeterminate: YES];
            }
            else 
            {                
                // cleanup - if the script didn't give us a proper status message, then we set one
                if ([[progressBarMessageTextField stringValue] isEqualToString: @""] || 
                    [[progressBarMessageTextField stringValue] isEqualToString: @"\n"] || 
                    [[progressBarMessageTextField stringValue] isEqualToString: @"Running..."])
                    [progressBarMessageTextField setStringValue: @"Task completed"];
                
                [progressBarIndicator setIndeterminate: NO];
                [progressBarIndicator setDoubleValue: 100];
            }
            
            // change button
            [progressBarCancelButton setTitle: @"Quit"];
            [progressBarCancelButton setEnabled: YES];
        }
        break;
            
        case PLATYPUS_WEBVIEW_OUTPUT:
        {
            //update controls for web output window
            [webOutputCancelButton setTitle: @"Quit"];
            [webOutputCancelButton setEnabled: YES];
            [webOutputProgressIndicator stopAnimation: self];
        }
        break;
            
        case PLATYPUS_DROPLET_OUTPUT:
        {
            [dropletProgressIndicator stopAnimation: self];
            [dropletDropFilesLabel setHidden: NO];
            [dropletMessageTextField setHidden: YES];
        }
        break;
        }
}
#else
// Adjust controls, windows, etc. once script is done executing
- (void)cleanupInterface {
    
    // if there are any remnants, we append them to output
    if (remnants != nil) {
        [self appendString:remnants];
        remnants = nil;
    }
    
    switch (interfaceType) {
            
        case PlatypusInterfaceType_None:
        case PlatypusInterfaceType_StatusMenu:
        {
            
        }
            break;

        case PlatypusInterfaceType_TextWindow:
        {
            // Update controls for text window
            [textWindowCancelButton setTitle:@"Quit"];
            [textWindowCancelButton setEnabled:YES];
            [textWindowProgressIndicator stopAnimation:self];
        }
            break;
            
        case PlatypusInterfaceType_ProgressBar:
        {            
            if (isDroppable) {
                [progressBarMessageTextField setStringValue:@"Drag files to process"];
                [progressBarIndicator setIndeterminate:YES];
            } else {
                // Cleanup - if the script didn't give us a proper status message, then we set one
                NSString *msg = [progressBarMessageTextField stringValue];
                if ([msg isEqualToString:@""] || [msg isEqualToString:@"\n"] || [msg isEqualToString:@"Running..."]) {
                    [progressBarMessageTextField setStringValue:@"Task completed"];
                }
                [progressBarIndicator setIndeterminate:NO];
                [progressBarIndicator setDoubleValue:100];
            }
            
            [progressBarIndicator stopAnimation:self];
            
            // Change button
            [progressBarCancelButton setTitle:@"Quit"];
            [progressBarCancelButton setEnabled:YES];
        }
            break;
            
        case PlatypusInterfaceType_WebView:
        {
            [webViewCancelButton setTitle:@"Quit"];
            [webViewCancelButton setEnabled:YES];
            [webViewProgressIndicator stopAnimation:self];
        }
            break;
            
        case PlatypusInterfaceType_Droplet:
        {
            [dropletProgressIndicator stopAnimation:self];
            [dropletDropFilesLabel setHidden:NO];
            [dropletMessageTextField setHidden:YES];
        }
            break;
    }
}
#endif

#pragma mark - Task

#ifdef PLATYPUS_HEAD
//
// construct arguments list etc.
// before actually running the script
//
-(void)prepareForExecution
{
    // if it is a "secure" script, we decode and write it to a temp directory
    // This used to be done by just writing to /tmp, but this method is more secure
    // and will result in the script file being created at a path that looks something
    // like this:  /var/folders/yV/yV8nyB47G-WRvC76fZ3Be++++TI/-Tmp-/
    // Kind of ugly, but it's the Apple-sanctioned secure way of doing things with temp files
    // Thanks to Matt Gallagher for this technique:
    // http://cocoawithlove.com/2009/07/temporary-files-and-folders-in-cocoa.html
    
    if (secureScript)
    {
        // create full path w. template
        NSString *tempFileTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent: TMP_SCRIPT_TEMPLATE];
        const char *tempFileTemplateCString = [tempFileTemplate fileSystemRepresentation];
        char *tempFileNameCString = (char *)malloc(strlen(tempFileTemplateCString) + 1);
        strcpy(tempFileNameCString, tempFileTemplateCString);
        
        // use mkstemp to expand template
        int fileDescriptor = mkstemp(tempFileNameCString);
        if (fileDescriptor == -1)
            [self fatalAlert: @"Unable to create temporary file" subText: [NSString stringWithFormat: @"Error %d in mkstemp()", errno]];
        close(fileDescriptor);
        
        // create nsstring from the c-string temp path
        NSString *tempScriptPath = [FILEMGR stringWithFileSystemRepresentation:tempFileNameCString length:strlen(tempFileNameCString)];
        free(tempFileNameCString);
        
        // write script to the temporary path
        [script writeToFile: tempScriptPath atomically: YES encoding: textEncoding error: NULL];
        
        // make sure writing it was successful
        if (![FILEMGR fileExistsAtPath: tempScriptPath])
            [self fatalAlert: @"Failed to write script file" subText: [NSString stringWithFormat: @"Could not create the temp file '%@'", tempScriptPath]];         
        
        scriptPath = [NSString stringWithString: tempScriptPath];
    }
    
    //clear arguments list and reconstruct it
    [arguments removeAllObjects];
    
    // first, add all specified arguments for interpreter
    [arguments addObjectsFromArray: interpreterArgs];
    
    // add script as argument to interpreter, if it exists
    if (![FILEMGR fileExistsAtPath: scriptPath])
        [self fatalAlert: @"Missing script" subText: @"Script missing at execution path"];
    [arguments addObject: scriptPath];
    
    // add arguments for script
    [arguments addObjectsFromArray: scriptArgs];
        
    //finally, add any file arguments we may have received as dropped/opened
    if ([jobQueue count] > 0) // we have files in the queue, to append as arguments
    {
        // we take the first job's arguments and put them into the arg list
        [arguments addObjectsFromArray: [jobQueue objectAtIndex: 0]];
        
        // then we remove the job from the queue
        //[[jobQueue objectAtIndex: 0] release]; // release
        [jobQueue removeObjectAtIndex: 0];
    }
}

-(void)executeScript
{    
    // we never execute script if there is one running
    if (isTaskRunning)
        return;
    
    if (outputType != PLATYPUS_NONE_OUTPUT)
        outputEmpty = NO;
    
    [self prepareForExecution];
    [self prepareInterfaceForExecution];
    
    isTaskRunning = YES;
    
    // run the task
    if (execStyle == PLATYPUS_PRIVILEGED_EXECUTION) //authenticated task
        [self executeScriptWithPrivileges];
    else //plain old nstask
        [self executeScriptWithoutPrivileges];
}

//launch regular user-privileged process using NSTask
-(void)executeScriptWithoutPrivileges
{    
    //initalize task
    task = [[NSTask alloc] init];
    
    //apply settings for task
    [task setLaunchPath: interpreter];
    [task setCurrentDirectoryPath: [[NSBundle mainBundle] resourcePath]];
    [task setArguments: arguments];
    
    // set output to file handle and start monitoring it if script provides feedback
    if (outputType != PLATYPUS_NONE_OUTPUT)
    {
        outputPipe = [NSPipe pipe];
        [task setStandardOutput: outputPipe];
        [task setStandardError: outputPipe];
        readHandle = [outputPipe fileHandleForReading];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getOutputData:) name: NSFileHandleReadCompletionNotification object:readHandle];
        [readHandle readInBackgroundAndNotify];
    }
    
    //set it off
    [task launch];
    
    // we wait until task exits if this is for the menu
    if (outputType == PLATYPUS_STATUSMENU_OUTPUT)
        [task waitUntilExit];
}

//launch task with admin privileges using Authentication Manager
-(void)executeScriptWithPrivileges
{    
    //initalize task
    privilegedTask = [[STPrivilegedTask alloc] init];
    
    //apply settings for task
    [privilegedTask setLaunchPath: interpreter];
    [privilegedTask setCurrentDirectoryPath: [[NSBundle mainBundle] resourcePath]];
    [privilegedTask setArguments: arguments];
    
    //set it off
    OSStatus err = [privilegedTask launch];
    if (err != errAuthorizationSuccess)
    {
        if (err == errAuthorizationCanceled)
        {
            outputEmpty = YES;
            [self taskFinished: NULL];
            return;
        }
        else // something went wrong
            [self fatalAlert: @"Failed to execute script" subText: [NSString stringWithFormat: @"Error %d occurred while executing script with privileges.", err]];
    }
    
    if (outputType != PLATYPUS_NONE_OUTPUT)
    {
        // Success!  Now, start monitoring output file handle for data
        readHandle = [privilegedTask outputFileHandle];
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(getOutputData:) name: NSFileHandleReadCompletionNotification object: readHandle];
        [readHandle readInBackgroundAndNotify];
    }
}

#else

// Construct arguments list etc. before actually running the script
- (void)prepareForExecution {
    
    // Clear arguments list and reconstruct it
    [arguments removeAllObjects];
    
    // First, add all specified arguments for interpreter
    [arguments addObjectsFromArray:interpreterArgs];
    
    // Add script as argument to interpreter, if it exists
    if (![FILEMGR fileExistsAtPath:scriptPath]) {
        [Alerts fatalAlert:@"Missing script" subTextFormat:@"Script missing at execution path %@", scriptPath];
    }
    [arguments addObject:scriptPath];
    
    // Add arguments for script
    [arguments addObjectsFromArray:scriptArgs];
    
    // If initial run of app, add any arguments passed in via the command line (argv)
    // Q: Why CLI args for GUI app typically launched from Finder?
    // A: Apparently helpful for certain use cases such as Firefox protocol handlers etc.
    if (commandLineArguments && [commandLineArguments count]) {
        [arguments addObjectsFromArray:commandLineArguments];
        commandLineArguments = nil;
    }
    
    // Finally, dequeue job and add arguments
    if ([jobQueue count] > 0) {
        ScriptExecJob *job = jobQueue[0];

        // We have files in the queue, to append as arguments
        // We take the first job's arguments and put them into the arg list
        if ([job arguments]) {
            [arguments addObjectsFromArray:[job arguments]];
        }
        stdinString = [[job standardInputString] copy];
        
        [jobQueue removeObjectAtIndex:0];
    }
}

- (void)executeScript {
    hasTaskRun = YES;
    
    // Never execute script if there is one running
    if (isTaskRunning) {
        return;
    }
    outputEmpty = NO;
    
    [self prepareForExecution];
    [self prepareInterfaceForExecution];
    
    isTaskRunning = YES;
    
    // Run the task
    if (execStyle == PlatypusExecStyle_Authenticated) {
        [self executeScriptWithPrivileges];
    } else {
        [self executeScriptWithoutPrivileges];
    }
}

- (NSString *)executeScriptForStatusMenu {

    [self prepareForExecution];
    [self prepareInterfaceForExecution];
    
    // Create task and apply settings
    task = [[NSTask alloc] init];
    [task setLaunchPath:interpreterPath];
    [task setCurrentDirectoryPath:[[NSBundle mainBundle] resourcePath]];
    [task setArguments:arguments];

    outputPipe = [NSPipe pipe];
    [task setStandardOutput:outputPipe];
    [task setStandardError:outputPipe];
    outputReadFileHandle = [outputPipe fileHandleForReading];
    
    // Set it off
    //PLog(@"Running task\n%@", [task humanDescription]);
    [task launch];
    // This is blocking
    [task waitUntilExit];
    
    NSData *outData = [outputReadFileHandle readDataToEndOfFile];
    return [[NSString alloc] initWithData:outData encoding:DEFAULT_TEXT_ENCODING];
}

// Launch regular user-privileged process using NSTask
- (void)executeScriptWithoutPrivileges {

    // Create task and apply settings
    task = [[NSTask alloc] init];
    [task setLaunchPath:interpreterPath];
    [task setCurrentDirectoryPath:[[NSBundle mainBundle] resourcePath]];
    [task setArguments:arguments];
    
    // Direct output to file handle and start monitoring it if script provides feedback
    outputPipe = [NSPipe pipe];
    [task setStandardOutput:outputPipe];
    [task setStandardError:outputPipe];
    outputReadFileHandle = [outputPipe fileHandleForReading];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gotOutputData:)
                                                 name:NSFileHandleReadCompletionNotification
                                               object:outputReadFileHandle];
    [outputReadFileHandle readInBackgroundAndNotify];
    
    // Set up stdin for writing
    inputPipe = [NSPipe pipe];
    [task setStandardInput:inputPipe];
    inputWriteFileHandle = [[task standardInput] fileHandleForWriting];
    
    // Set it off
    //PLog(@"Running task\n%@", [task humanDescription]);
    [task launch];
    
    // Write input, if any, to stdin, and then close
    if (stdinString) {
        [inputWriteFileHandle writeData:[stdinString dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [inputWriteFileHandle closeFile];
    stdinString = nil;    
}

// Launch task with admin privileges using Authentication API
- (void)executeScriptWithPrivileges {
    // Create task
    privilegedTask = [[STPrivilegedTask alloc] init];
    [privilegedTask setLaunchPath:interpreterPath];
    [privilegedTask setCurrentDirectoryPath:[[NSBundle mainBundle] resourcePath]];
    [privilegedTask setArguments:arguments];
    
    // Set it off
    PLog(@"Running task\n%@", [privilegedTask description]);
    OSStatus err = [privilegedTask launch];
    if (err != errAuthorizationSuccess) {
        if (err == errAuthorizationCanceled) {
            outputEmpty = YES;
            [self taskFinished:nil];
            return;
        }  else {
            // Something went wrong
            [Alerts fatalAlert:@"Failed to execute script"
                 subTextFormat:@"Error %d occurred while executing script with privileges.", (int)err];
        }
    }
    
    // Success! Now, start monitoring output file handle for data
    outputReadFileHandle = [privilegedTask outputFileHandle];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gotOutputData:)
                                                 name:NSFileHandleReadCompletionNotification
                                               object:outputReadFileHandle];
    [outputReadFileHandle readInBackgroundAndNotify];
}
#endif

#pragma mark - Task completion

// OK, called when we receive notification that task is finished
// Some cleaning up to do, controls need to be adjusted, etc.
#ifdef PLATYPUS_HEAD
-(void)taskFinished: (NSNotification *)aNotification
{        
    // if task already quit, we return
    if (!isTaskRunning) 
        return;
    
    isTaskRunning = NO;
    
    // make sure task is dead.  Ideally we'd like to do the same for privileged tasks, but that's just not possible w/o process id
    if (execStyle == PLATYPUS_NORMAL_EXECUTION && task != NULL && [task isRunning])
        [task terminate];
    
    // did we receive all the data?
    if (outputEmpty) // if no data left we do the clean up 
        [self cleanup];
    
    //if we're using the "secure" script, we must remove the temporary clear-text one in temp directory if there is one
    if (secureScript && [FILEMGR fileExistsAtPath: scriptPath])
        [FILEMGR removeItemAtPath: scriptPath error: nil];
    
    // we quit now if the app isn't set to continue running
    if (!remainRunning)
    {
        [[NSApplication sharedApplication] terminate: self];
        return;
    }
    
    // if there are more jobs waiting for us, execute
    if ([jobQueue count] > 0)
        [self executeScript];
}

-(void)cleanup
{    
    // we never do cleanup if the task is running
    if (isTaskRunning) 
        return;
    
    // Stop observing the filehandle for data since task is done
    [[NSNotificationCenter defaultCenter] removeObserver: self name: NSFileHandleReadCompletionNotification object: readHandle];
    
    // We make sure to clear the filehandle of any remaining data
    if (readHandle != NULL)
    {
        NSData *data;
        while ((data = [readHandle availableData]) && [data length])
            [self appendOutput: data];
    }
    
    // now, reset all controls etc., general cleanup since task is done    
    [self cleanupInterface];    
}

#pragma mark - Output

//  read from the file handle and append it to the text window
-(void) getOutputData: (NSNotification *)aNotification
{
    //get the data from notification
    NSData *data = [[aNotification userInfo] objectForKey: NSFileHandleNotificationDataItem];
    
    //make sure there's actual data
    if ([data length]) 
    {
        outputEmpty = NO;
        
        //append the output to the text field        
        [self appendOutput: data];
        
        // we schedule the file handle to go and read more data in the background again.
        [[aNotification object] readInBackgroundAndNotify];
    }
    else
    {
        outputEmpty = YES;
        if (!isTaskRunning)
            [self cleanup];
    }
}

//
// this function receives all new data dumped out by the script and appends it to text field
// it is *relatively* memory efficient (given the nature of NSTextView) and doesn't leak, as far as I can tell...
//
-(void)appendOutput: (NSData *)data
{    
    // we decode the script output according to specified character encoding
    NSMutableString *outputString = [[NSMutableString alloc] initWithData: data encoding: textEncoding];
    
    if (!outputString)
        return;
    
    // we parse output if output type is progress bar, to get progress indicator values and display string
    if (outputType == PLATYPUS_PROGRESSBAR_OUTPUT || outputType == PLATYPUS_DROPLET_OUTPUT)
    {
        if (remnants != NULL && [remnants length] > 0)
            [outputString insertString: remnants atIndex: 0];
        
        // parse the data just dumped out
        NSMutableArray *lines = [NSMutableArray arrayWithArray: [outputString componentsSeparatedByString: @"\n"]];
        
        // if the line did not end with a newline, it wasn't a complete line of output
        // Thus, we store the last line and then delete it from the outputstring
        // It'll be appended next time we get output
        if ([(NSString *)[lines lastObject] length] > 0)
        {
            if (remnants != NULL) { [remnants release]; remnants = NULL; }
            remnants = [[NSString alloc] initWithString: [lines lastObject]];
            [outputString deleteCharactersInRange: NSMakeRange([outputString length]-[remnants length], [remnants length])];
        }
        else
            remnants = NULL;
        
        [lines removeLastObject];
        
        // parse output looking for commands; if none, add line to output text field
        int i;
        for (i = 0; i < [lines count]; i++)
        {
            NSString *theLine = [lines objectAtIndex: i];
            
            // if the line is empty, we ignore it
            if ([theLine caseInsensitiveCompare: @""] == NSOrderedSame)
                continue;
            
            // lines starting with PROGRESS:\d+ are interpreted as percentage to set progress bar at
            if ([theLine hasPrefix: @"PROGRESS:"])
            {            
                NSString *progressPercent = [theLine substringFromIndex: 9];
                [progressBarIndicator setIndeterminate: NO];
                [progressBarIndicator setDoubleValue: [progressPercent doubleValue]];
            }
            else
            {
                [dropletMessageTextField setStringValue: theLine];
                [progressBarMessageTextField setStringValue: theLine];
            }
        }
    }
    
    // append the ouput to the text in the text field
    NSTextStorage *text = [outputTextView textStorage];
    [text replaceCharactersInRange: NSMakeRange([text length], 0) withString: outputString];
    
    // if web output, we continually re-render to accomodate incoming data, else we scroll down
    if (outputType == PLATYPUS_WEBVIEW_OUTPUT)
        [[webOutputWebView mainFrame] loadHTMLString: [outputTextView string] baseURL: [NSURL fileURLWithPath: [[NSBundle mainBundle] resourcePath]] ];
    else if (outputType == PLATYPUS_TEXTWINDOW_OUTPUT || outputType == PLATYPUS_PROGRESSBAR_OUTPUT)
        [outputTextView scrollRangeToVisible: NSMakeRange([text length], 0)];
    
    [outputString release];
}

#pragma mark - Interface actions

//run open panel, made available to apps that are droppable
-(IBAction)openFiles: (id)sender
{
    //create open panel
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setPrompt: @"Open"];
    [oPanel setAllowsMultipleSelection: YES];
    [oPanel setCanChooseDirectories: acceptDroppedFolders];   
    
    // build array of acceptable file types
    NSMutableArray *types = nil;
    if (!acceptAnyDroppedItem)
    {
        types = [NSMutableArray array];
        [types addObjectsFromArray: droppableSuffixes];
        [types addObjectsFromArray: droppableFileTypes];
    }
    
    if ([oPanel runModalForDirectory: nil file: nil types: types] == NSOKButton)
    {
        int ret = [self addDroppedFilesJob: [oPanel filenames]];
        if (!isTaskRunning && ret)
            [self executeScript];
    }
}

// show / hide the details text field in progress bar output
-(IBAction)toggleDetails: (id)sender
{
    NSRect winRect = [progressBarWindow frame];
    
    if ([sender state] == NSOffState)
    {
        [progressBarWindow setShowsResizeIndicator: NO];
        winRect.origin.y += 224;
        winRect.size.height -= 224;        
        [progressBarWindow setFrame: winRect display: TRUE animate: TRUE];
    }
    else
    {
        [progressBarWindow setShowsResizeIndicator: YES];
        winRect.origin.y -= 224;
        winRect.size.height += 224;
        [progressBarWindow setFrame: winRect display: TRUE animate: TRUE];
    }
}


// save output in text field to file when Save to File menu item is invoked
-(IBAction)saveToFile: (id)sender
{
    if (outputType != PLATYPUS_TEXTWINDOW_OUTPUT && outputType != PLATYPUS_WEBVIEW_OUTPUT)
        return;
    
    NSString *outSuffix = (outputType == PLATYPUS_WEBVIEW_OUTPUT) ? @"html" : @"txt";
    NSString *fileName = [NSString stringWithFormat: @"%@ Output.%@", appName, outSuffix];
    
    NSSavePanel *sPanel = [NSSavePanel savePanel];
    [sPanel setPrompt: @"Save"];
    
    if ([sPanel runModalForDirectory: nil file: fileName] == NSFileHandlingPanelOKButton)
        [[outputTextView string] writeToFile: [sPanel filename] atomically: YES encoding: textEncoding error: nil];
}

// save only works for text window, web view output types
// and open only works for droppable apps that accept files as script args

-(BOOL)validateMenuItem: (NSMenuItem*)anItem 
{    
    //save to file item
    if ([[anItem title] isEqualToString:@"Save to File…"] && 
        (outputType != PLATYPUS_TEXTWINDOW_OUTPUT && outputType != PLATYPUS_WEBVIEW_OUTPUT))
        return NO;
    
    //open should only work if it's a droppable app
    if ([[anItem title] isEqualToString:@"Open…"] &&
        (!isDroppable || !acceptsFiles || [jobQueue count] >= PLATYPUS_MAX_QUEUE_JOBS))
        return NO;
    
    return YES;
}

-(IBAction)cancel: (id)sender
{
    if (task != NULL)
        [task terminate];
    
    if ([[sender title] isEqualToString: @"Quit"])
        [[NSApplication sharedApplication] terminate: self];
}

#pragma mark - Service handling

// service

-(void)dropService: (NSPasteboard*)pb userData: (NSString *)userData error: (NSString **)err
{
    NSArray* types = [pb types];
    BOOL ret = 0;
    id data = nil;
    
    // file(s)
    if (acceptsFiles && [types containsObject: NSFilenamesPboardType] && (data = [pb propertyListForType: NSFilenamesPboardType]))
        ret = [self addDroppedFilesJob: data]; // files
    else if (acceptsText && [types containsObject: NSStringPboardType] && (data = [pb stringForType: NSStringPboardType]))
        ret = [self addDroppedTextJob: data]; // text
    else // unknown
    {
        *err = @"Data type in pasteboard cannot be handled by this application.";
        return;
    }
    
    if (!isTaskRunning && ret)
        [self executeScript];
}

// text snippet drag handling

-(void)doString: (NSPasteboard *)pboard userData: (NSString *)userData error: (NSString **)error 
{
    if (!isDroppable || !acceptsText || [jobQueue count] >= PLATYPUS_MAX_QUEUE_JOBS)
        return;
    
    NSString *pboardString = [pboard stringForType:NSStringPboardType];
    
    int ret = [self addDroppedTextJob: pboardString];
    
    if (!isTaskRunning && ret)
        [self executeScript];
}

#pragma mark - Create drop job

-(BOOL)addDroppedTextJob: (NSString *)text
{
    if (!isDroppable || [jobQueue count] >= PLATYPUS_MAX_QUEUE_JOBS)
        return NO;
    
    if ([text length] <= 0) // ignore empty strings
        return NO;
    
    // add job with text as argument for script
    NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity: ARG_MAX];
    [args addObject: text];
    [jobQueue addObject: args];
    [args release];
    return YES;
}

// drop files processing

-(BOOL)addDroppedFilesJob: (NSArray *)files
{
    if (!isDroppable || !acceptsFiles || [jobQueue count] >= PLATYPUS_MAX_QUEUE_JOBS)
        return NO;
    
    // Let's see what we have
    int i;
    NSMutableArray *acceptedFiles = [[[NSMutableArray alloc] init] autorelease];
    
    // Only accept the drag if at least one of the files meets the required types
    for (i = 0; i < [files count]; i++)
    {            
        // if we accept this item, add it to list of accepted files
        if ([self acceptableFileType: [files objectAtIndex: i]])
            [acceptedFiles addObject: [files objectAtIndex: i]];
    }
    
    // if at this point there are no accepted files, we refuse drop
    if ([acceptedFiles count] == 0)
        return NO;
    
    // we create a processing job and add the files as arguments, accept drop
    NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity: ARG_MAX];//this object is released in -prepareForExecution function
    
    [args addObjectsFromArray: acceptedFiles];
    [jobQueue addObject: args];
    [args release];
    return YES;
}

/*****************************************************************
 
 Returns whether a given file is accepted by the suffix/types 
 criterion specified in AppSettings.plist
 
 *****************************************************************/

-(BOOL)acceptableFileType: (NSString *)file
{
    int i;
    BOOL isDir;
    
    // Check if it's a folder. If so, we only accept it if 'fold' is specified as accepted file type
    if ([FILEMGR fileExistsAtPath: file isDirectory: &isDir] && isDir && acceptDroppedFolders)
        return YES;
    
    if (acceptAnyDroppedItem)
        return YES;
    
    // see if it has accepted suffix
    for (i = 0; i < [droppableSuffixes count]; i++)
        if ([file hasSuffix: [droppableSuffixes objectAtIndex: i]])
            return YES;
    
    // see if it has accepted file type
    NSString *fileType = NSHFSTypeOfFile(file);
    for(i = 0; i < [droppableFileTypes count]; i++)
        if([fileType isEqualToString: [droppableFileTypes objectAtIndex: i]])
            return YES;
    
    return NO;
}

#pragma mark - Drag and drop handling

#else
- (void)taskFinished:(NSNotification *)aNotification {
    // Ignore if not current script task
    if (([aNotification object] != task && [aNotification object] != privilegedTask) || !isTaskRunning) {
        return;
    }
    isTaskRunning = NO;
    PLog(@"Task finished");
        
    // Did we receive all the data?
    // If no data left, we do clean up
    if (outputEmpty) {
        [self cleanup];
    }
    
    // If there are more jobs waiting for us, execute
    if ([jobQueue count] > 0 /*&& remainRunning*/) {
        [self executeScript];
    }
}

- (void)cleanup {
    if (isTaskRunning) {
        return;
    }
    // Stop observing the filehandle for data since task is done
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSFileHandleReadCompletionNotification
                                                  object:outputReadFileHandle];
    
    // We make sure to clear the filehandle of any remaining data
    if (outputReadFileHandle != nil) {
        NSData *data;
        while ((data = [outputReadFileHandle availableData]) && [data length]) {
            [self parseOutput:data];
        }
    }
    
    // Now, reset all controls etc., general cleanup since task is done
    [self cleanupInterface];
}

#pragma mark - Output

// Read from the file handle and append it to the text window
- (void)gotOutputData:(NSNotification *)aNotification {
    // Get the data from notification
    NSData *data = [aNotification userInfo][NSFileHandleNotificationDataItem];
    
    // Make sure there's actual data
    if ([data length]) {
        outputEmpty = NO;
        
        // Append the output to the text field
        [self parseOutput:data];
        
        // We schedule the file handle to go and read more data in the background again.
        [[aNotification object] readInBackgroundAndNotify];
    }
    else {
        PLog(@"Output empty");
        outputEmpty = YES;
        if (!isTaskRunning) {
            [self cleanup];
        }
        if (!remainRunning) {
            [[NSApplication sharedApplication] terminate:self];
        }
    }
}

- (void)parseOutput:(NSData *)data {
    // Create string from output data
    NSMutableString *outputString = [[NSMutableString alloc] initWithData:data encoding:DEFAULT_TEXT_ENCODING];
    
    if (outputString == nil) {
        PLog(@"Warning: Output string is nil");
        return;
    }
    
    PLog(@"Output:%@", outputString);
    
    if (remnants) {
        [outputString insertString:remnants atIndex:0];
    }
    
    // Parse line by line
    NSMutableArray *lines = [[outputString componentsSeparatedByString:@"\n"] mutableCopy];
    
    // If the string did not end with a newline, it wasn't a complete line of output
    // Thus, we store this last non-newline-terminated string
    // It'll be prepended next time we get output
    if ([[lines lastObject] length] > 0) { // Output didn't end with a newline
        remnants = [lines lastObject];
    } else {
        remnants = nil;
    }
    
    [lines removeLastObject];
    
    NSURL *locationURL = nil;
    
    // Parse output looking for commands; if none, append line to output text field
    for (NSString *theLine in lines) {

#if 0
        if ([theLine length] == 0) {
            [self appendString:@""];
            continue;
        }
#endif
        
        if ([theLine isEqualToString:@"QUITAPP"]) {
            [[NSApplication sharedApplication] terminate:self];
            continue;
        }
        
        if ([theLine isEqualToString:@"REFRESH"]) {
            [self clearOutputBuffer];
            continue;
        }
        
        if ([theLine hasPrefix:@"NOTIFICATION:"]) {
            NSString *notificationString = [theLine substringFromIndex:13];
            [self showNotification:notificationString];
            continue;
        }
        
        if ([theLine hasPrefix:@"ALERT:"]) {
            NSString *alertString = [theLine substringFromIndex:6];
            NSArray *components = [alertString componentsSeparatedByString:CMDLINE_ARG_SEPARATOR];
            [Alerts alert:components[0] subText:[components count] > 1 ? components[1] : components[0]];
            continue;
        }
        
        // Special commands to control progress bar interface
        if (interfaceType == PlatypusInterfaceType_ProgressBar) {
            
            // Set progress bar status
            // Lines starting with PROGRESS:\d+ are interpreted as percentage to set progress bar
            if ([theLine hasPrefix:@"PROGRESS:"]) {
                NSString *progressPercentString = [theLine substringFromIndex:9];
                if ([progressPercentString hasSuffix:@"%"]) {
                    progressPercentString = [progressPercentString substringToIndex:[progressPercentString length]-1];
                }
                
                // Parse percentage using number formatter
                NSNumberFormatter *numFormatter = [[NSNumberFormatter alloc] init];
                numFormatter.numberStyle = NSNumberFormatterDecimalStyle;
                NSNumber *percentageNumber = [numFormatter numberFromString:progressPercentString];
                
                if (percentageNumber != nil) {
                    [progressBarIndicator setIndeterminate:NO];
                    [progressBarIndicator setDoubleValue:[percentageNumber doubleValue]];
                }
                continue;
            }
            // Toggle visibility of details text field
            else if ([theLine isEqualToString:@"DETAILS:SHOW"]) {
                [self showDetails];
                continue;
            }
            else if ([theLine isEqualToString:@"DETAILS:HIDE"]) {
                [self hideDetails];
                continue;
            }
        }
        
        if (interfaceType == PlatypusInterfaceType_WebView && [theLine hasPrefix:@"LOCATION:"]) {
            NSString *urlString = [theLine substringFromIndex:9];
            urlString = [urlString stringByReplacingOccurrencesOfString:@" " withString:@""];
            locationURL = [NSURL URLWithString:urlString];
            [webView setToolTip:@"LOCATION"];
        }
        
        [self appendString:theLine];
        
        // OK, line wasn't a command understood by the wrapper
        // Show it in our GUI text field
        if (interfaceType == PlatypusInterfaceType_Droplet) {
            [dropletMessageTextField setStringValue:theLine];
        }
        if (interfaceType == PlatypusInterfaceType_ProgressBar) {
            [progressBarMessageTextField setStringValue:theLine];
        }
    }
    
    // If web output, we continually re-render to accomodate incoming data
    if (interfaceType == PlatypusInterfaceType_WebView) {
        if (locationURL) {
            // Load the provided URL
            [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:locationURL]];
        } else {
            // Otherwise, just load script output as HTML string
            NSURL *resourcePathURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]];
            [[webView mainFrame] loadHTMLString:[outputTextView string] baseURL:resourcePathURL];
        }
    }
    
    if (IsTextViewScrollableInterfaceType(interfaceType)) {
        [outputTextView scrollRangeToVisible:NSMakeRange([[outputTextView textStorage] length], 0)];
    }
}

- (void)clearOutputBuffer {
    NSTextStorage *textStorage = [outputTextView textStorage];
    NSRange range = NSMakeRange(0, [textStorage length]-1);
    [textStorage beginEditing];
    [textStorage replaceCharactersInRange:range withString:@""];
    [textStorage endEditing];
}

- (void)appendString:(NSString *)string {
    PLog(@"Appending output: \"%@\"", string);

    if (interfaceType == PlatypusInterfaceType_None) {
        fprintf(stderr, "%s\n", [string cStringUsingEncoding:DEFAULT_TEXT_ENCODING]);
        return;
    }
    
    // This code is optimized to use replaceCharactersInRange on the text view
    // in order to reduce the cost of redraws and string manipulation
    NSTextStorage *textStorage = [outputTextView textStorage];
    NSRange appendRange = NSMakeRange([textStorage length], 0);
    [textStorage beginEditing];
    [textStorage replaceCharactersInRange:appendRange withString:string];
    [textStorage replaceCharactersInRange:NSMakeRange([textStorage length], 0) withString:@"\n"];
#if 0
    NSString *repl = [NSString stringWithFormat:@"%@\n", string];
    [textStorage replaceCharactersInRange:appendRange withString:repl];
#endif
    [textStorage endEditing];
}

#pragma mark - Interface actions

// Run open panel, made available to apps that accept files
- (IBAction)openFiles:(id)sender {
    
    // Create open panel
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:YES];
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:acceptDroppedFolders];
    
    // Set acceptable file types - default allows all
    if (!acceptAnyDroppedItem) {
        NSArray *fileTypes = [droppableUniformTypes count] > 0 ? droppableUniformTypes : droppableSuffixes;
        [oPanel setAllowedFileTypes:fileTypes];
    }
    
    if ([oPanel runModal] == NSFileHandlingPanelOKButton) {
        // Convert URLs to paths
        NSMutableArray *filePaths = [NSMutableArray array];        
        for (NSURL *url in [oPanel URLs]) {
            [filePaths addObject:[url path]];
        }
        
        BOOL success = [self addDroppedFilesJob:filePaths];
        
        if (!isTaskRunning && success) {
            [self executeScript];
        }
        
    } else {
        // Canceled in open file dialog
        if (!remainRunning) {
            [[NSApplication sharedApplication] terminate:self];
        }
    }
}

// Show / hide the details text field in progress bar interface
- (IBAction)toggleDetails:(id)sender {
    NSRect winRect = [progressBarWindow frame];
    
    NSSize minSize = [progressBarWindow minSize];
    NSSize maxSize = [progressBarWindow maxSize];
    
    if ([sender state] == NSOffState) {
        winRect.origin.y += detailsHeight;
        winRect.size.height -= detailsHeight;
        minSize.height -= detailsHeight;
        maxSize.height -= detailsHeight;

    }
    else {
        winRect.origin.y -= detailsHeight;
        winRect.size.height += detailsHeight;
        minSize.height += detailsHeight;
        maxSize.height += detailsHeight;
    }
    
    [DEFAULTS setBool:([sender state] == NSOnState) forKey:ScriptExecDefaultsKey_ShowDetails];
    [progressBarWindow setMinSize:minSize];
    [progressBarWindow setMaxSize:maxSize];
    [progressBarWindow setShowsResizeIndicator:([sender state] == NSOnState)];
    [progressBarWindow setFrame:winRect display:TRUE animate:TRUE];
}

// Show the details text field in progress bar interface
- (IBAction)showDetails {
    if ([progressBarDetailsTriangle state] == NSOffState) {
        [progressBarDetailsTriangle performClick:progressBarDetailsTriangle];
    }
}

// Hide the details text field in progress bar interface
- (IBAction)hideDetails {
    if ([progressBarDetailsTriangle state] != NSOffState) {
        [progressBarDetailsTriangle performClick:progressBarDetailsTriangle];
    }
}

// Save output in text field to file when Save to File menu item is invoked
- (IBAction)saveToFile:(id)sender {
    if (IsTextStyledInterfaceType(interfaceType) == NO) {
        return;
    }
    NSString *outSuffix = (interfaceType == PlatypusInterfaceType_WebView) ? @"html" : @"txt";
    NSString *fileName = [NSString stringWithFormat:@"%@-Output.%@", appName, outSuffix];
    
    NSSavePanel *sPanel = [NSSavePanel savePanel];
    [sPanel setPrompt:@"Save"];
    [sPanel setNameFieldStringValue:fileName];
    
    if ([sPanel runModal] == NSFileHandlingPanelOKButton) {
        NSError *err;
        BOOL success = [[outputTextView string] writeToFile:[[sPanel URL] path] atomically:YES encoding:DEFAULT_TEXT_ENCODING error:&err];
        if (!success) {
            [Alerts alert:@"Error writing file" subText:[err localizedDescription]];
        }
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem {
    
    // Status item menus are always enabled
    if (interfaceType == PlatypusInterfaceType_StatusMenu) {
        return YES;
    }
    // Save to file
    SEL selector = [anItem action];
    if (IsTextStyledInterfaceType(interfaceType) && selector == @selector(saveToFile:)) {
        return YES;
    }
    // Open should only work if it's a droppable app that accepts files
    if (acceptsFiles && selector == @selector(openFiles:)) {
        return YES;
    }
    // Change text size
    if (IsTextSizableInterfaceType(interfaceType) &&
        (selector == @selector(makeTextBigger:) || selector == @selector(makeTextSmaller:))) {
        return YES;
    }
    if ([anItem action] == @selector(menuItemSelected:)) {
        return YES;
    }
    
    return NO;
}

- (IBAction)cancel:(id)sender {
    if (task != nil && [task isRunning]) {
        PLog(@"Task cancelled");
        [task terminate];
    }
    
    if ([[sender title] isEqualToString:@"Quit"]) {
        [[NSApplication sharedApplication] terminate:self];
    }
}

#pragma mark - Text resizing

- (void)changeFontSize:(CGFloat)delta {
    
    if (interfaceType == PlatypusInterfaceType_WebView) {
        // Web View
        if (delta > 0) {
            [webView makeTextLarger:self];
        } else {
            [webView makeTextSmaller:self];
        }
    } else {
        // Text field
        CGFloat newFontSize = [textFont pointSize] + delta;
        if (newFontSize < 5.0) {
            newFontSize = 5.0;
        }

        textFont = [[NSFontManager sharedFontManager] convertFont:textFont toSize:newFontSize];
        [outputTextView setFont:textFont];
        [DEFAULTS setObject:@((float)newFontSize) forKey:ScriptExecDefaultsKey_UserFontSize];
        [outputTextView didChangeText];
    }
}

- (IBAction)makeTextBigger:(id)sender {
    [self changeFontSize:1];
}

- (IBAction)makeTextSmaller:(id)sender {
    [self changeFontSize:-1];
}
#endif

#pragma mark - Service handling

- (void)dropService:(NSPasteboard *)pb userData:(NSString *)userData error:(NSString **)err {
    PLog(@"Received drop service data");
    NSArray *types = [pb types];
    BOOL ret = 0;
    id data = nil;
    
    if (acceptsFiles && [types containsObject:NSFilenamesPboardType] && (data = [pb propertyListForType:NSFilenamesPboardType])) {
        ret = [self addDroppedFilesJob:data];  // Files
    } else if (acceptsText && [types containsObject:NSURLPboardType] && [NSURL URLFromPasteboard:pb] != nil) {
        NSURL *fileURL = [NSURL URLFromPasteboard:pb];
        ret = [self addDroppedTextJob:[fileURL absoluteString]];  // URL
    } else if (acceptsText && [types containsObject:NSStringPboardType] && (data = [pb stringForType:NSStringPboardType])) {
        ret = [self addDroppedTextJob:data];  // Text
    } else {
        // Unknown
        *err = @"Data type in pasteboard cannot be handled by this application.";
        return;
    }
    
    if (isTaskRunning == NO && ret) {
        [self executeScript];
    }
}

#ifdef PLATYPUS_HEAD
-(NSDragOperation)draggingEntered: (id <NSDraggingInfo>)sender 
{ 
    BOOL acceptDrag = NO;
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    // if this is a file being dragged
    if ([[pboard types] containsObject: NSFilenamesPboardType] && acceptsFiles)
    {
        // loop through files, see if any of the dragged files are acceptable
        int i;
        NSArray *files = [pboard propertyListForType: NSFilenamesPboardType];
        
        for (i = 0; i < [files count]; i++)
            if ([self acceptableFileType: [files objectAtIndex: i]])
                acceptDrag = YES;
    }
    // see if this is a string being dragged
    else if ([[pboard types] containsObject: NSStringPboardType] && acceptsText)
        acceptDrag = YES;
    
    if (acceptDrag)
    {
        // we shade the window if output is droplet mode
        if (outputType == PLATYPUS_DROPLET_OUTPUT)
        {
            [dropletShader setAlphaValue: 0.3];
            [dropletShader setHidden: NO];
        }
        return NSDragOperationLink;
    }
    
    return NSDragOperationNone;
}

-(void)draggingExited: (id <NSDraggingInfo>)sender;
{
    if (outputType == PLATYPUS_DROPLET_OUTPUT)
        [dropletShader setHidden: YES];
}

-(BOOL)performDragOperation: (id <NSDraggingInfo>)sender
{ 
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    if ([[pboard types] containsObject: NSStringPboardType])
        return [self addDroppedTextJob: [pboard stringForType: NSStringPboardType]];
    else
        return [self addDroppedFilesJob: [pboard propertyListForType: NSFilenamesPboardType]];
    
    return NO;
}

// once the drag is over, we immediately execute w. files as arguments if not already processing
-(void)concludeDragOperation: (id <NSDraggingInfo>)sender
{
    if (outputType == PLATYPUS_DROPLET_OUTPUT)
        [dropletShader setHidden: YES];
    
    if (!isTaskRunning && [jobQueue count] > 0)
        [NSTimer scheduledTimerWithTimeInterval: 0.05 target: self selector: @selector(executeScript) userInfo: nil repeats: NO];
}

-(NSDragOperation)draggingUpdated: (id <NSDraggingInfo>)sender
{
    return [self draggingEntered: sender]; // this is needed to keep link instead of the green plus sign on web view
}

#pragma mark - Web View Output updating

#else

#pragma mark - Text snippet drag handling

- (void)doString:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error {
    if (acceptsText == NO) {
        return;
    }
    
    NSString *pboardString = [pboard stringForType:NSStringPboardType];
    BOOL success = [self addDroppedTextJob:pboardString];
    
    if (!isTaskRunning && success) {
        [self executeScript];
    }
}

#pragma mark - Add job to queue

- (BOOL)addDroppedTextJob:(NSString *)text {
    if (!acceptsText) {
        return NO;
    }
    ScriptExecJob *job = [ScriptExecJob jobWithArguments:nil andStandardInput:text];
    [jobQueue addObject:job];
    return YES;
}

// Processing dropped files
- (BOOL)addDroppedFilesJob:(NSArray <NSString *> *)files {
    if (!acceptsFiles) {
        return NO;
    }
    
    // We only accept the drag if at least one of the files meets the required types
    NSMutableArray *acceptedFiles = [NSMutableArray array];
    for (NSString *file in files) {
        if ([self isAcceptableFileType:file]) {
            [acceptedFiles addObject:file];
        }
    }
    if ([acceptedFiles count] == 0) {
        return NO;
    }
    
    // We create a job and add the files as arguments
    ScriptExecJob *job = [ScriptExecJob jobWithArguments:acceptedFiles andStandardInput:nil];
    [jobQueue addObject:job];
    
    // Add to Open Recent menu
    for (NSString *path in acceptedFiles) {
        [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:path]];
    }
    
    return YES;
}

- (BOOL)addURLJob:(NSString *)urlStr {
    ScriptExecJob *job = [ScriptExecJob jobWithArguments:@[urlStr] andStandardInput:nil];
    [jobQueue addObject:job];
    return YES;
}

- (BOOL)addMenuItemSelectedJob:(NSString *)menuItemTitle {
    ScriptExecJob *job = [ScriptExecJob jobWithArguments:@[menuItemTitle] andStandardInput:nil];
    [jobQueue addObject:job];
    return YES;
}

/*********************************************
 Returns whether a given file matches the file
 suffixes/UTIs specified in AppSettings.plist
 *********************************************/

- (BOOL)isAcceptableFileType:(NSString *)file {
    
    // Check if it's a folder. If so, we only accept it if folders are accepted
    BOOL isDir;
    BOOL exists = [FILEMGR fileExistsAtPath:file isDirectory:&isDir];
    if (!exists) {
        return NO;
    }
    if (isDir) {
        return acceptDroppedFolders;
    }
    
    if (acceptAnyDroppedItem) {
        return YES;
    }
    
    for (NSString *suffix in droppableSuffixes) {
        if ([file hasSuffix:suffix]) {
            return YES;
        }
    }
    
    for (NSString *uti in droppableUniformTypes) {
        NSError *outErr = nil;
        NSString *fileType = [WORKSPACE typeOfFile:file error:&outErr];
        if (fileType == nil) {
            NSLog(@"Unable to determine file type for %@: %@", file, [outErr localizedDescription]);
        } else if ([WORKSPACE type:fileType conformsToType:uti]) {
            return YES;
        }
    }
    
    return NO;
}
#endif

#pragma mark - Drag and drop handling

// Check file types against acceptable drop types here before accepting them
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    // Prevent dragging from NSOpenPanels
    // draggingSource returns nil if the source is not in the same application
    // as the destination. We decline any drags from within the app.
    if ([sender draggingSource]) {
        return NSDragOperationNone;
    }
    
    BOOL acceptDrag = NO;
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    // String dragged
    if ([[pboard types] containsObject:NSStringPboardType] && acceptsText) {
        acceptDrag = YES;
    }
    // File dragged
    else if ([[pboard types] containsObject:NSFilenamesPboardType] && acceptsFiles) {
        // Loop through files, see if any of the dragged files are acceptable
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        
        for (NSString *file in files) {
            if ([self isAcceptableFileType:file]) {
                acceptDrag = YES;
                break;
            }
        }
    }
    
    if (acceptDrag) {
        // Shade the window if interface type is droplet
        if (interfaceType == PlatypusInterfaceType_Droplet) {
            [dropletShaderView setAlphaValue:0.3];
            [dropletShaderView setHidden:NO];
        }
        PLog(@"Dragged items accepted");
        return NSDragOperationLink;
    }
    
    PLog(@"Dragged items refused");
    return NSDragOperationNone;
}

#ifdef PLATYPUS_HEAD
-(void)webView: (WebView *)sender didFinishLoadForFrame: (WebFrame *)frame
{
    NSScrollView *scrollView = [[[[webOutputWebView mainFrame] frameView] documentView] enclosingScrollView];    
    NSRect bounds = [[[[webOutputWebView mainFrame] frameView] documentView] bounds];
    [[scrollView documentView] scrollPoint: NSMakePoint(0, bounds.size.height)];
}

#pragma mark - Status Menu
#else
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
    return YES;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
    // Hide droplet shading on drag exit
    if (interfaceType == PlatypusInterfaceType_Droplet) {
        [dropletShaderView setHidden:YES];
    }
}
#endif

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    // Determine drag data type and dispatch to job queue
    if ([[pboard types] containsObject:NSStringPboardType]) {
        return [self addDroppedTextJob:[pboard stringForType:NSStringPboardType]];
    }
    else if ([[pboard types] containsObject:NSFilenamesPboardType]) {
        return [self addDroppedFilesJob:[pboard propertyListForType:NSFilenamesPboardType]];
    }
    return NO;
}

#ifdef PLATYPUS_HEAD
-(void)menuNeedsUpdate: (NSMenu *)menu
{    
    int i;
    
    // run script and wait until we've received all the script output
    [self executeScript];
    while (isTaskRunning)
        usleep(50000); // microseconds
    
    // create an array of lines by separating output by newline
    NSMutableArray *lines = [NSMutableArray  arrayWithArray: [[textOutputTextView string] componentsSeparatedByString: @"\n"]];
    
    // clean out any trailing newlines
    while ([[lines lastObject] isEqualToString: @""])
        [lines removeLastObject];
    
    // create a dict of text attributes based on settings
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    //textBackground, NSBackgroundColorAttributeName, 
                                    textForeground, NSForegroundColorAttributeName, 
                                    textFont, NSFontAttributeName,
                                    NULL];
    
    // remove all items of previous output
    while ([statusItemMenu numberOfItems] > 2)
        [statusItemMenu removeItemAtIndex: 0];
    
    //populate menu with output from task
    for (i = [lines count]-1; i >= 0; i--)
    {        
        // create the menu item
        NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle: @"" action: NULL keyEquivalent: @""] autorelease];
        
        // set the formatted menu item string
        NSAttributedString *attStr = [[[NSAttributedString alloc] initWithString: [lines objectAtIndex: i] attributes: textAttributes] autorelease];
        [menuItem setAttributedTitle: attStr];
        [menu insertItem: menuItem atIndex: 0];
    }
}

#pragma mark - Utility methods

// show error alert and then exit application
-(void)fatalAlert: (NSString *)message subText: (NSString *)subtext
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText: message];
    [alert setInformativeText: subtext];
    [alert setAlertStyle: NSCriticalAlertStyle];
    [alert runModal];
    [alert release];
    [[NSApplication sharedApplication] terminate: self];
}

#else
// Once the drag is over, we immediately execute w. files as arguments if not already processing
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {
    // Shade droplet
    if (interfaceType == PlatypusInterfaceType_Droplet) {
        [dropletShaderView setHidden:YES];
    }
    // Fire off the job queue if nothing is running
    if (!isTaskRunning && [jobQueue count] > 0) {
        [NSTimer scheduledTimerWithTimeInterval:0.0f target:self selector:@selector(executeScript) userInfo:nil repeats:NO];
    }
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
    // This is needed to keep link instead of the green plus sign on web view
    // and also required to reject non-acceptable dragged items.
    return [self draggingEntered:sender];
}

#pragma mark - Web View

/**************************************************
 Called whenever web view re-renders.
 Scroll to the bottom on each re-rendering unless
 we have received LOCATION: from the script
 **************************************************/

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    if (frame != [webView mainFrame]) {
        // Ignore embedded iframes
        return;
    }
    if ([[sender toolTip] isEqualToString:@"LOCATION"]) {
        // The web view was marked as having just loaded a URL using LOCATION
        [sender setToolTip:@""];
        return;
    }
    // Scroll to the bottom of the enclosing scroll view
    NSScrollView *scrollView = [[[[webView mainFrame] frameView] documentView] enclosingScrollView];
    NSRect bounds = [[[[webView mainFrame] frameView] documentView] bounds];
    [[scrollView documentView] scrollPoint:NSMakePoint(0, bounds.size.height)];
}

#pragma mark - Status Menu

/**************************************************
 Called whenever status item is clicked.  We run
 script, get output and generate menu with the ouput
 **************************************************/

- (void)menuNeedsUpdate:(NSMenu *)menu {
    
    // Run script and wait until we've received all output
    NSString *outputStr = [self executeScriptForStatusMenu];
    
    // Create an array of lines by separating output by newline
    NSMutableArray *lines = [[outputStr componentsSeparatedByString:@"\n"] mutableCopy];
    
    // Clean out any trailing newlines
    while ([[lines lastObject] isEqualToString:@""]) {
        [lines removeLastObject];
    }
    
    // Remove all menu items from previous output
    while ([statusItemMenu numberOfItems] > 2) {
        [statusItemMenu removeItemAtIndex:0];
    }
    
    // Populate menu with output from task
    for (NSInteger i = [lines count] - 1; i >= 0; i--) {
        NSString *line = lines[i];
        NSImage *icon = nil;
        BOOL disabled = NO;
        
        // ---- creates a separator item
        if ([line hasPrefix:@"----"]) {
            [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
            continue;
        }
        
        // Syntax to disable menu item
        NSString *disabledCmd = @"DISABLED|";
        if ([line hasPrefix:disabledCmd]) {
            disabled = YES;
            line = [line substringFromIndex:[disabledCmd length]];
        }
        
        // Parse syntax setting item icon
        if ([line hasPrefix:@"MENUITEMICON|"]) {
            NSArray *tokens = [line componentsSeparatedByString:CMDLINE_ARG_SEPARATOR];
            if ([tokens count] < 3) {
                continue;
            }
            NSString *imageToken = tokens[1];
            // Is it a bundled image?
            icon = [NSImage imageNamed:imageToken];
            
            // If not, it could be a URL
            if (icon == nil) {
                // Or a file system path
                BOOL isDir;
                if ([FILEMGR fileExistsAtPath:imageToken isDirectory:&isDir] && !isDir) {
                    icon = [[NSImage alloc] initByReferencingFile:imageToken];
                } else {
                    NSURL *url = [NSURL URLWithString:imageToken];
                    if (url != nil) {
                        icon = [[NSImage alloc] initWithContentsOfURL:url];
                    }
                }
            }
            
            [icon setSize:NSMakeSize(16, 16)];
            line = tokens[2];
        }
        
        // Parse syntax to handle submenus
        NSMenu *submenu = nil;
        if ([line hasPrefix:@"SUBMENU|"]) {
            NSMutableArray *tokens = [[line componentsSeparatedByString:CMDLINE_ARG_SEPARATOR] mutableCopy];
            if ([tokens count] < 3) {
                continue;
            }
            NSString *menuName = tokens[1];
            [tokens removeObjectAtIndex:0];
            [tokens removeObjectAtIndex:0];
            
            // Create submenu
            submenu = [[NSMenu alloc] initWithTitle:menuName];
            for (NSString *t in tokens) {
                if ([t hasPrefix:@"----"]) {
                    [submenu addItem:[NSMenuItem separatorItem]];
                    continue;
                }
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:t action:@selector(menuItemSelected:) keyEquivalent:@""];
                [submenu addItem:item];
            }
            
            line = menuName;
        }
        
        // Create the menu item
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:line action:@selector(menuItemSelected:) keyEquivalent:@""];
        if (submenu) {
            [menuItem setAction:nil];
            [menuItem setSubmenu:submenu];
        }
        
        // Set the formatted menu item string
        if (statusItemUsesSystemFont) {
            [menuItem setTitle:line];
        } else {
            // Create a dict of text attributes based on settings
            NSDictionary *textAttributes = \
            @{  NSForegroundColorAttributeName:textForegroundColor,
                NSFontAttributeName:textFont   };
            
            NSAttributedString *attStr = [[NSAttributedString alloc] initWithString:line attributes:textAttributes];
            [menuItem setAttributedTitle:attStr];
        }
        
        if (icon != nil) {
            [menuItem setImage:icon];
        }
        if (disabled) {
            [menuItem setEnabled:NO];
            [menuItem setAction:nil];
        }
        
        [menu insertItem:menuItem atIndex:0];
    }
}

- (IBAction)menuItemSelected:(id)sender {
    [self addMenuItemSelectedJob:[sender title]];
    if (!isTaskRunning && [jobQueue count] > 0) {
        [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(executeScript) userInfo:nil repeats:NO];
    }
}

#pragma mark - Window delegate methods

- (void)windowWillClose:(NSNotification *)notification {
    NSWindow *win = [notification object];
    if (win == dropletWindow && interfaceType == PlatypusInterfaceType_Droplet) {
        [[NSApplication sharedApplication] terminate:self];
    }
}

#pragma mark - Utility methods

- (void)showNotification:(NSString *)notificationText {
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    [notification setTitle:appName];
    [notification setInformativeText:notificationText];
    [notification setSoundName:NSUserNotificationDefaultSoundName];
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

#endif
@end
