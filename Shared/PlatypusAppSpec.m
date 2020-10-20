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

// PlatypusAppSpec is a wrapper class around an NSDictionary containing all
// the information / specifications needed to create a Platypus application.

#import "Common.h"
#import "PlatypusAppSpec.h"
#import "PlatypusScriptUtils.h"
#import "NSWorkspace+Additions.h"
#import "NSFileManager+TempFiles.h"

@implementation PlatypusAppSpec

#ifdef PLATYPUS_HEAD
#pragma mark - Creation
/*****************************************
 - init / dealloc functions
*****************************************/

-(PlatypusAppSpec *)init
{
    if (self = [super init]) 
    {
        properties = [[NSMutableDictionary alloc] initWithCapacity: MAX_APPSPEC_PROPERTIES];
    }
    return self;
}
#else
#pragma mark - Create spec

- (instancetype)initWithDefaults {
    if (self = [self init]) {
        [self setDefaults];
    }
    return self;
}
#endif

#ifdef PLATYPUS_HEAD
-(PlatypusAppSpec *)initWithDefaults
{
    if (self = [self init]) 
    {
        [self setDefaults];
    }
    return self;
}

-(PlatypusAppSpec *)initWithDefaultsFromScript: (NSString *)scriptPath
{
    if (self = [self init]) 
    {
        [self setDefaultsForScript: scriptPath];
    }
    return self;
}

-(PlatypusAppSpec *)initWithDictionary: (NSDictionary *)dict
{
    if (self = [self init]) 
    {
        [self setDefaults];
        [properties addEntriesFromDictionary: dict];
    }
    return self;
}

-(PlatypusAppSpec *)initWithProfile: (NSString *)filePath
{
    return [self initWithDictionary: [NSMutableDictionary dictionaryWithContentsOfFile: filePath]];
}

+(PlatypusAppSpec *)specWithDefaults
{
    return [[[PlatypusAppSpec alloc] initWithDefaults] autorelease];
}

+(PlatypusAppSpec *)specWithDictionary: (NSDictionary *)dict
{
    return [[[PlatypusAppSpec alloc] initWithDictionary: dict] autorelease];
}

+(PlatypusAppSpec *)specFromProfile: (NSString *)filePath
{
    return [[[PlatypusAppSpec alloc] initWithProfile: filePath] autorelease];
}

+(PlatypusAppSpec *)specWithDefaultsFromScript: (NSString *)scriptPath
{
    return [[[PlatypusAppSpec alloc] initWithDefaultsFromScript: scriptPath] autorelease];
}

-(void)dealloc
{
    [properties release];
    [super dealloc];
}

#pragma mark - Instance methods

/**********************************
    init a spec with default values for everything
**********************************/

-(void)setDefaults
{
    // stamp the spec with the creator
    [properties setObject: PROGRAM_STAMP                                                forKey: @"Creator"];

    //prior properties
    [properties setObject: CMDLINE_EXEC_PATH                                            forKey: @"ExecutablePath"];
    [properties setObject: CMDLINE_NIB_PATH                                                forKey: @"NibPath"];
    [properties setObject: DEFAULT_DESTINATION_PATH                                     forKey: @"Destination"];
    
    [properties setValue: [NSNumber numberWithBool: NO]                                    forKey: @"DestinationOverride"];
    [properties setValue: [NSNumber numberWithBool: NO]                                    forKey: @"DevelopmentVersion"];
    [properties setValue: [NSNumber numberWithBool: YES]                                forKey: @"OptimizeApplication"];
    [properties setValue: [NSNumber numberWithBool: YES]                                forKey: @"UseXMLPlistFormat"];
    
    // primary attributes    
    [properties setObject: DEFAULT_APP_NAME                                                forKey: @"Name"];
    [properties setObject: @""                                                            forKey: @"ScriptPath"];
    [properties setObject: DEFAULT_OUTPUT_TYPE                                            forKey: @"Output"];
    [properties setObject: CMDLINE_ICON_PATH                                            forKey: @"IconPath"];
    
    // secondary attributes
    [properties setObject: DEFAULT_INTERPRETER                                            forKey: @"Interpreter"];
    [properties setObject: [NSMutableArray array]                                        forKey: @"InterpreterArgs"];
    [properties setObject: [NSMutableArray array]                                        forKey: @"ScriptArgs"];
    [properties setObject: DEFAULT_VERSION                                                forKey: @"Version"];
    [properties setObject: DEFAULT_BUNDLE_ID                                            forKey: @"Identifier"];
    [properties setObject: NSFullUserName()                                                forKey: @"Author"];
    
    [properties setValue: [NSNumber numberWithBool: NO]                                    forKey: @"Droppable"];
    [properties setValue: [NSNumber numberWithBool: NO]                                    forKey: @"Secure"];
    [properties setValue: [NSNumber numberWithBool: NO]                                    forKey: @"Authentication"];
    [properties setValue: [NSNumber numberWithBool: YES]                                forKey: @"RemainRunning"];
    [properties setValue: [NSNumber numberWithBool: NO]                                    forKey: @"ShowInDock"];
        
    // bundled files
    [properties setObject: [NSMutableArray array]                                        forKey: @"BundledFiles"];
    
    // file/drag acceptance properties
    [properties setObject: [NSMutableArray arrayWithObject: @"*"]                        forKey: @"Suffixes"];
    [properties setObject: [NSMutableArray arrayWithObjects: @"****", @"fold", nil]     forKey: @"FileTypes"];
    [properties setObject: DEFAULT_ROLE                                                    forKey: @"Role"];
    [properties setObject: [NSNumber numberWithBool: NO]                                forKey: @"AcceptsText"];
    [properties setObject: [NSNumber numberWithBool: YES]                               forKey: @"AcceptsFiles"];
    [properties setObject: [NSNumber numberWithBool: NO]                                forKey: @"DeclareService"];
    [properties setObject: @""                                                          forKey: @"DocIcon"];
    
    // text output settings
    [properties setObject: [NSNumber numberWithInt: DEFAULT_OUTPUT_TXT_ENCODING]        forKey: @"TextEncoding"];
    [properties setObject: DEFAULT_OUTPUT_FONT                                            forKey: @"TextFont"];
    [properties setObject: [NSNumber numberWithFloat: DEFAULT_OUTPUT_FONTSIZE]            forKey: @"TextSize"];
    [properties setObject: DEFAULT_OUTPUT_FG_COLOR                                        forKey: @"TextForeground"];
    [properties setObject: DEFAULT_OUTPUT_BG_COLOR                                        forKey: @"TextBackground"];

    // status item settings
    [properties setObject: DEFAULT_STATUSITEM_DTYPE                                     forKey: @"StatusItemDisplayType"];
    [properties setObject: DEFAULT_APP_NAME                                                forKey: @"StatusItemTitle"];
    [properties setObject: [NSData data]                                                forKey: @"StatusItemIcon"];
}

/********************************************************
 inits with default values and then analyse script, 
 load default values based on analysed script properties
 ********************************************************/

-(void)setDefaultsForScript: (NSString *)scriptPath
{
    // start with a dict populated with defaults
    [self setDefaults];
    
    // set script path
    [self setProperty: scriptPath forKey: @"ScriptPath"];
    
    //determine app name based on script filename
    NSString *appName = [ScriptAnalyser appNameFromScriptFileName: scriptPath];
    [self setProperty: appName forKey: @"Name"];
        
    //find an interpreter for it
    NSString *interpreter = [ScriptAnalyser determineInterpreterForScriptFile: scriptPath];
    if ([interpreter isEqualToString: @""])
        interpreter = DEFAULT_INTERPRETER;
    else
    {
        // get parameters to interpreter
        NSMutableArray *shebangCmdComponents = [NSMutableArray arrayWithArray: [ScriptAnalyser getInterpreterFromShebang: scriptPath]];
        [shebangCmdComponents removeObjectAtIndex: 0];
        [self setProperty: shebangCmdComponents forKey: @"InterpreterArgs"];
    }
    [self setProperty: interpreter forKey: @"Interpreter"];
    
    // find parent folder wherefrom we create destination path of app bundle
    NSString *parentFolder = [scriptPath stringByDeletingLastPathComponent];
    NSString *destPath = [NSString stringWithFormat: @"%@/%@.app", parentFolder, appName];
    [self setProperty: destPath forKey: @"Destination"];
    [self setProperty: [PlatypusAppSpec standardBundleIdForAppName: appName usingDefaults: NO] forKey: @"Identifier"];
}

/****************************************
 This function creates the Platypus app
 based on the data contained in the spec.
****************************************/

-(BOOL)create
{
    int      i;
    NSString *contentsPath, *macosPath, *resourcesPath;
    NSString *execDestinationPath, *infoPlistPath, *iconPath, *docIconPath, *bundledFileDestPath, *nibDestPath;
    NSString *execPath, *nibPath, *bundledFilePath;
    NSString *appSettingsPlistPath;
    NSString *b_enc_script = @"";
    NSMutableDictionary    *appSettingsPlist;
    NSFileManager *fileManager = FILEMGR;
    
    // get temporary directory, make sure it's kosher.  Apparently NSTemporaryDirectory() can return nil
    // see http://www.cocoadev.com/index.pl?NSTemporaryDirectory
    NSString *tmpPath = NSTemporaryDirectory();
    if (!tmpPath)
        tmpPath = @"/tmp/";
    
    // Now, make sure conditions are acceptable
    
    // make sure we can write to temp path
    if (![fileManager isWritableFileAtPath: tmpPath])
    {
        error = [NSString stringWithFormat: @"Could not write to the temp directory '%@'.", tmpPath]; 
        return 0;
    }

    //check if app already exists
    if ([fileManager fileExistsAtPath: [properties objectForKey: @"Destination"]])
    {
        if (![[properties objectForKey: @"DestinationOverride"] boolValue])
        {
            error = [NSString stringWithFormat: @"App already exists at path %@. Use -y flag to overwrite.", [properties objectForKey: @"Destination"]];
            return 0;
        }
        else
            [self report: [NSString stringWithFormat: @"Overwriting app at path %@", [properties objectForKey: @"Destination"]]];
    }
    
    // check if executable exists
    execPath = [properties objectForKey: @"ExecutablePath"];
    if (![fileManager fileExistsAtPath: execPath] || ![fileManager isReadableFileAtPath: execPath])
    {
        [self report: [NSString stringWithFormat: @"Executable %@ does not exist. Aborting.", execPath, nil]];
        return NO;
    }
    
    // check if source nib exists
    nibPath = [properties objectForKey: @"NibPath"];
    if (![fileManager fileExistsAtPath: nibPath] || ![fileManager isReadableFileAtPath: nibPath])
    {
        [self report: [NSString stringWithFormat: @"Nib file %@ does not exist. Aborting.", nibPath, nil]];
        return NO;
    }
    
    ////////////////////////// CREATE THE FOLDER HIERARCHY //////////////////////////
    
    // we begin by creating the application bundle at temp path
    
    [self report: @"Creating app bundle hierarchy"];
    
    //Application.app bundle
    tmpPath = [tmpPath stringByAppendingString: [[properties objectForKey: @"Destination"] lastPathComponent]];
    [fileManager createDirectoryAtPath: tmpPath withIntermediateDirectories: NO attributes: nil error: nil];
    
    //.app/Contents
    contentsPath = [tmpPath stringByAppendingString:@"/Contents"];
    [fileManager createDirectoryAtPath: contentsPath withIntermediateDirectories: NO attributes: nil error: nil];
    
    //.app/Contents/MacOS
    macosPath = [contentsPath stringByAppendingString:@"/MacOS"];
    [fileManager createDirectoryAtPath: macosPath withIntermediateDirectories: NO attributes: nil error: nil];
    
    //.app/Contents/Resources
    resourcesPath = [contentsPath stringByAppendingString:@"/Resources"];
    [fileManager createDirectoryAtPath: resourcesPath withIntermediateDirectories: NO attributes: nil error: nil];
            
    ////////////////////////// COPY FILES TO THE APP BUNDLE //////////////////////////////////
    
    [self report: @"Copying executable to bundle"];
    
    //copy exec file
    //.app/Contents/Resources/MacOS/ScriptExec
    execDestinationPath = [macosPath stringByAppendingString:@"/"];
    execDestinationPath = [execDestinationPath stringByAppendingString: [properties objectForKey: @"Name"]]; 
    [fileManager copyItemAtPath: execPath toPath: execDestinationPath error: nil];
    [PlatypusUtility setPermissions: S_IRWXU | S_IRWXG | S_IROTH forFile: execDestinationPath];
    
    //copy nib file to app bundle
    //.app/Contents/Resources/MainMenu.nib
    [self report: @"Copying nib file to bundle"];
    nibDestPath = [resourcesPath stringByAppendingString:@"/MainMenu.nib"];
    [fileManager copyItemAtPath: nibPath toPath: nibDestPath error: nil];
        
    // if optimize application is set, we see if we can compile the nib file
    if ([[properties objectForKey: @"OptimizeApplication"] boolValue] == YES && [fileManager fileExistsAtPath: IBTOOL_PATH])
    {
        [self report: @"Optimizing nib file"];
        
        NSTask *ibToolTask = [[NSTask alloc] init];
        [ibToolTask setLaunchPath: IBTOOL_PATH];
        [ibToolTask setArguments: [NSArray arrayWithObjects: @"--strip", nibDestPath, nibDestPath, nil]];
        [ibToolTask launch];
        [ibToolTask waitUntilExit];
        [ibToolTask release];
    }
    
    // create script file in app bundle
    //.app/Contents/Resources/script
    [self report: @"Copying script"];
    
    if ([[properties objectForKey: @"Secure"] boolValue])
        b_enc_script = [NSData dataWithContentsOfFile: [properties objectForKey: @"ScriptPath"]];
    else
    {
        NSString *scriptFilePath = [resourcesPath stringByAppendingString:@"/script"];
        // make a symbolic link instead of copying script if this is a dev version
        if ([[properties objectForKey: @"DevelopmentVersion"] boolValue] == YES)
            [fileManager createSymbolicLinkAtPath: scriptFilePath withDestinationPath: [properties objectForKey: @"ScriptPath"] error: nil];
        else // copy script over
            [fileManager copyItemAtPath: [properties objectForKey: @"ScriptPath"] toPath: scriptFilePath error: nil];
        
        [PlatypusUtility setPermissions: S_IRWXU | S_IRWXG | S_IROTH forFile: scriptFilePath];
    }
        
    //create AppSettings.plist file
    //.app/Contents/Resources/AppSettings.plist
    [self report: @"Creating property lists"];
    appSettingsPlist = [NSMutableDictionary dictionaryWithCapacity: PROGRAM_MAX_LIST_ITEMS];
    [appSettingsPlist setObject: [properties objectForKey: @"Authentication"] forKey: @"RequiresAdminPrivileges"];
    [appSettingsPlist setObject: [properties objectForKey: @"Droppable"] forKey: @"Droppable"];
    [appSettingsPlist setObject: [properties objectForKey: @"RemainRunning"] forKey: @"RemainRunningAfterCompletion"];
    [appSettingsPlist setObject: [properties objectForKey: @"Secure"] forKey: @"Secure"];
    [appSettingsPlist setObject: [properties objectForKey: @"Output"] forKey: @"OutputType"];
    [appSettingsPlist setObject: [properties objectForKey: @"Interpreter"] forKey: @"ScriptInterpreter"];
    [appSettingsPlist setObject: PROGRAM_STAMP forKey: @"Creator"];
    [appSettingsPlist setObject: [properties objectForKey: @"InterpreterArgs"] forKey: @"InterpreterArgs"];
    [appSettingsPlist setObject: [properties objectForKey: @"ScriptArgs"] forKey: @"ScriptArgs"];
    
    // we need only set text settings for the output types that use this information
    if ([[properties objectForKey: @"Output"] isEqualToString: @"Progress Bar"] ||
        [[properties objectForKey: @"Output"] isEqualToString: @"Text Window"] ||
        [[properties objectForKey: @"Output"] isEqualToString: @"Status Menu"])
    {
        [appSettingsPlist setObject: [properties objectForKey: @"TextFont"] forKey: @"TextFont"];
        [appSettingsPlist setObject: [properties objectForKey: @"TextSize"] forKey: @"TextSize"];
        [appSettingsPlist setObject: [properties objectForKey: @"TextForeground"] forKey: @"TextForeground"];
        [appSettingsPlist setObject: [properties objectForKey: @"TextBackground"] forKey: @"TextBackground"];
        [appSettingsPlist setObject: [properties objectForKey: @"TextEncoding"] forKey: @"TextEncoding"];
    }
    
    // likewise, status menu settings are only written if that is the output type
    if ([[properties objectForKey: @"Output"] isEqualToString: @"Status Menu"] == YES)
    {
        [appSettingsPlist setObject: [properties objectForKey: @"StatusItemDisplayType"] forKey: @"StatusItemDisplayType"];
        [appSettingsPlist setObject: [properties objectForKey: @"StatusItemTitle"] forKey: @"StatusItemTitle"];
        [appSettingsPlist setObject: [properties objectForKey: @"StatusItemIcon"] forKey: @"StatusItemIcon"];
    }
    
    // we  set the suffixes/file types in the AppSettings.plist if app is droppable
    if ([[properties objectForKey: @"Droppable"] boolValue] == YES)
    {        
        [appSettingsPlist setObject: [properties objectForKey: @"Suffixes"] forKey: @"DropSuffixes"];
        [appSettingsPlist setObject: [properties objectForKey: @"FileTypes"] forKey: @"DropTypes"];
    }
    [appSettingsPlist setObject: [properties objectForKey: @"AcceptsFiles"] forKey: @"AcceptsFiles"];
    [appSettingsPlist setObject: [properties objectForKey: @"AcceptsText"] forKey: @"AcceptsText"];

    // if script is "secured" we encoded it into AppSettings property list
    if ([[properties objectForKey: @"Secure"] boolValue])
        [appSettingsPlist setObject: [NSKeyedArchiver archivedDataWithRootObject: b_enc_script] forKey: @"TextSettings"];
    
    appSettingsPlistPath = [resourcesPath stringByAppendingString:@"/AppSettings.plist"];
    
    // write the app settings plist
    if (![[properties objectForKey: @"UseXMLPlistFormat"] boolValue])
    {
        NSData *binPlistData = [NSPropertyListSerialization dataFromPropertyList: appSettingsPlist
                                                                          format: NSPropertyListBinaryFormat_v1_0
                                                                errorDescription: nil];
        [binPlistData writeToFile: appSettingsPlistPath atomically: YES];
    }
    else
        [appSettingsPlist writeToFile: appSettingsPlistPath atomically: YES];
    
    //create icon
    //.app/Contents/Resources/appIcon.icns
    if ([properties objectForKey: @"IconPath"] && ![[properties objectForKey: @"IconPath"] isEqualToString: @""])
    {
        [self report: @"Writing application icon"];
        iconPath = [resourcesPath stringByAppendingString:@"/appIcon.icns"];
        [fileManager copyItemAtPath: [properties objectForKey: @"IconPath"] toPath: iconPath error: nil];
    }
    
    if ([properties objectForKey: @"DocIcon"] && ![[properties objectForKey: @"DocIcon"] isEqualToString: @""])
    {
        [self report: @"Writing document icon"];
        docIconPath = [resourcesPath stringByAppendingString:@"/docIcon.icns"];
        [fileManager copyItemAtPath: [properties objectForKey: @"DocIcon"] toPath: docIconPath error: nil];
    }
          
    //create Info.plist file
    //.app/Contents/Info.plist
    [self report: @"Creating Info.plist"];
    NSDictionary *infoPlist = [self infoPlist];
    infoPlistPath = [contentsPath stringByAppendingString:@"/Info.plist"];
    
    [self report: @"Writing Info.plist"];
    if (![[properties objectForKey: @"UseXMLPlistFormat"] boolValue]) // if binary
    {
        NSData *binPlistData = [NSPropertyListSerialization dataFromPropertyList: infoPlist
                                                                          format: NSPropertyListBinaryFormat_v1_0
                                                                errorDescription: nil];
        [binPlistData writeToFile: infoPlistPath atomically: YES];
    }
    else
        [infoPlist writeToFile: infoPlistPath atomically: YES]; // if xml
            
    //copy files in file list to the Resources folder
    //.app/Contents/Resources/*
    [self report: @"Copying bundled files"];
    
    for (i = 0; i < [[properties objectForKey: @"BundledFiles"] count]; i++)
    {
        bundledFilePath = [[properties objectForKey: @"BundledFiles"] objectAtIndex: i];
        bundledFileDestPath = [resourcesPath stringByAppendingString:@"/"];
        bundledFileDestPath = [bundledFileDestPath stringByAppendingString: [bundledFilePath lastPathComponent]];
        
        NSString *srcFileName = [bundledFilePath lastPathComponent];
        [self report: [NSString stringWithFormat: @"Copying %@ to bundle", srcFileName]];
        
        // if it's a development version, we just symlink it
        if ([[properties objectForKey: @"DevelopmentVersion"] boolValue] == YES)
            [fileManager createSymbolicLinkAtPath: bundledFileDestPath withDestinationPath: bundledFilePath error: nil];
        else // else we copy it 
            [fileManager copyItemAtPath: bundledFilePath toPath: bundledFileDestPath error: nil];
    }

    ////////////////////////////////// COPY APP OVER TO FINAL DESTINATION /////////////////////////////////
    
    // we've created the application bundle in the temporary directory
    // now it's time to move it to the destination specified by the user
    [self report: @"Moving app to destination"];
    
    // first, let's see if there's anything there.  If we have override set on, we just delete that stuff.
    if ([fileManager fileExistsAtPath: [properties objectForKey: @"Destination"]] && [[properties objectForKey: @"DestinationOverride"] boolValue])
        [fileManager removeItemAtPath: [properties objectForKey: @"Destination"] error: nil];

    //if delete wasn't a success and there's still something there
    if ([fileManager fileExistsAtPath: [properties objectForKey: @"Destination"]]) 
    {
        [fileManager removeItemAtPath: tmpPath error: nil];
        error = @"Could not remove pre-existing item at destination path";
        return 0;
    }
    
    // now, move the newly created app to the destination
    [fileManager moveItemAtPath: tmpPath toPath: [properties objectForKey: @"Destination"] error: nil];//move
    if (![fileManager fileExistsAtPath: [properties objectForKey: @"Destination"]]) //if move wasn't a success
    {
        [fileManager removeItemAtPath: tmpPath error: nil];
        error = @"Failed to create application at the specified destination";
        return 0;
    }
    if ([[properties objectForKey: @"DeclareService"] boolValue])
    {
        [self report: @"Updating Dynamic Services"];
        NSUpdateDynamicServices();
    }
    
    [self report: @"Done"];

    // notify workspace that the file changed
    [[NSWorkspace sharedWorkspace] noteFileSystemChanged:  [properties objectForKey: @"Destination"]];
    
    return 1;
}

-(NSDictionary *)infoPlist
{
    // create the Info.plist dictionary
    NSMutableDictionary *infoPlist = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                      
                        @"English",                                 @"CFBundleDevelopmentRegion",
                        [properties objectForKey: @"Name"],         @"CFBundleExecutable", 
                        [properties objectForKey: @"Name"],         @"CFBundleName",
                        [properties objectForKey: @"Name"],         @"CFBundleDisplayName",
                        [NSString stringWithFormat: @"© %d %@", [[NSCalendarDate calendarDate] yearOfCommonEra], [properties objectForKey: @"Author"] ],             @"NSHumanReadableCopyright", 
                        [properties objectForKey: @"Version"],      @"CFBundleVersion", 
                        [properties objectForKey: @"Identifier"],   @"CFBundleIdentifier",  
                        [properties objectForKey: @"ShowInDock"],   @"LSUIElement",
                        @"6.0",                                     @"CFBundleInfoDictionaryVersion",
                        @"APPL",                                    @"CFBundlePackageType",
                        @"MainMenu",                                @"NSMainNibFile",
                        PROGRAM_MIN_SYS_VERSION,                    @"LSMinimumSystemVersion",
                        @"NSApplication",                           @"NSPrincipalClass", 
                                      
                                      nil];
    
    if (![[properties objectForKey: @"IconPath"] isEqualToString: @""])
        [infoPlist setObject: @"appIcon.icns" forKey: @"CFBundleIconFile"]; 
    
    // if droppable, we declare the accepted file types
    if ([[properties objectForKey: @"Droppable"] boolValue] == YES)
    {
        NSMutableDictionary    *typesAndSuffixesDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                     [properties objectForKey: @"Suffixes"], @"CFBundleTypeExtensions",//extensions
                                                     [properties objectForKey: @"FileTypes"], @"CFBundleTypeOSTypes",//os types
                                                     [properties objectForKey: @"Role"], @"CFBundleTypeRole", nil];//viewer or editor?
        
        // document icon
        if ([properties objectForKey: @"DocIcon"] && [[NSFileManager defaultManager] fileExistsAtPath: [properties objectForKey: @"DocIcon"]])
            [typesAndSuffixesDict setObject: @"docIcon.icns" forKey: @"CFBundleTypeIconFile"];
        
        // set file types and suffixes
        [infoPlist setObject: [NSArray arrayWithObject: typesAndSuffixesDict] forKey: @"CFBundleDocumentTypes"];
        
        // add service settings to Info.plist
        if ([[properties objectForKey: @"DeclareService"] boolValue])
        {
            // service data type handling
            NSMutableArray      *sendTypes = [NSMutableArray arrayWithCapacity: 2];
            if ([[properties objectForKey: @"AcceptsFiles"] boolValue])
                [sendTypes addObject: @"NSFilenamesPboardType"];
            if ([[properties objectForKey: @"AcceptsText"] boolValue])
                [sendTypes addObject: @"NSStringPboardType"];
            
            NSString            *appName = [properties objectForKey: @"Name"];
            NSMutableDictionary *serviceDict = [NSMutableDictionary dictionaryWithCapacity: 10];
            NSDictionary        *menuItemDict = [NSDictionary dictionaryWithObject: [NSString stringWithFormat: @"Process with %@", appName] forKey: @"default"];
            
            [serviceDict setObject: menuItemDict  forKey: @"NSMenuItem"];
            [serviceDict setObject: @"dropService"  forKey: @"NSMessage"];
            [serviceDict setObject: appName         forKey: @"NSPortName"];
            [serviceDict setObject: sendTypes       forKey: @"NSSendTypes"];
            [infoPlist setObject: [NSArray arrayWithObject: serviceDict] forKey: @"NSServices"];
        }
    }
    return infoPlist;
}

-(void)report: (NSString *)str
{
    fprintf(stderr, "%s\n", [str UTF8String]);
    [[NSNotificationCenter defaultCenter] postNotificationName: @"PlatypusAppSpecCreationNotification" object: str];
}

/********************************************
    Make sure the data in the spec is sane
*********************************************/

-(BOOL)verify
{
    BOOL isDir;
    
    if (![[properties objectForKey: @"Destination"] hasSuffix: @"app"])
    {
        error = @"Destination must end with .app";
        return 0;
    }

    if ([[properties objectForKey: @"Name"] isEqualToString: @""])
    {
        error = @"Empty app name";
        return 0;
    }
    
    if (![FILEMGR fileExistsAtPath: [properties objectForKey: @"ScriptPath"] isDirectory: &isDir] || isDir)
    {
        error = [NSString stringWithFormat: @"Script not found at path '%@'", [properties objectForKey: @"ScriptPath"], nil];
        return 0;
    }
    
    if (![FILEMGR fileExistsAtPath: [properties objectForKey: @"NibPath"] isDirectory: &isDir])
    {
        error = [NSString stringWithFormat: @"Nib not found at path '%@'", [properties objectForKey: @"NibPath"], nil];
        return 0;
    }
    
    if (![FILEMGR fileExistsAtPath: [properties objectForKey: @"ExecutablePath"] isDirectory: &isDir] || isDir)
    {
        error = [NSString stringWithFormat: @"Executable not found at path '%@'", [properties objectForKey: @"ExecutablePath"], nil];
        return 0;
    }
    
    //make sure destination directory exists
    if (![FILEMGR fileExistsAtPath: [[properties objectForKey: @"Destination"] stringByDeletingLastPathComponent] isDirectory: &isDir] || !isDir)
    {
        error = [NSString stringWithFormat: @"Destination directory '%@' does not exist.", [[properties objectForKey: @"Destination"] stringByDeletingLastPathComponent], nil];
        return 0;
    }
    
    //make sure we have write privileges for the destination directory
    if (![FILEMGR isWritableFileAtPath: [[properties objectForKey: @"Destination"] stringByDeletingLastPathComponent]])
    {
        error = [NSString stringWithFormat: @"Don't have permission to write to the destination directory '%@'", [properties objectForKey: @"Destination"]] ;
        return 0;
    }
    
    return 1;
}

/********************************
 Dump properties array to a file
********************************/

-(void)dumpToFile: (NSString *)filePath
{
    [properties writeToFile: filePath atomically: YES];
}

-(void)dump
{
    fprintf(stdout, "%s\n", [[properties description] UTF8String]);
}

// generates the command that would create this spec using flags to the platypus command line tool

-(NSString *)commandString
{
    int i;
    NSString *checkboxParamStr = @"";
    NSString *iconParamStr = @"", *versionString = @"", *authorString = @"";
    NSString *suffixesString = @"", *filetypesString = @"", *parametersString = @"";
    NSString *textEncodingString = @"", *textOutputString = @"", *statusMenuOptionsString = @""; 
    
    // checkbox parameters
    if ([[properties objectForKey: @"Authentication"] boolValue])
        checkboxParamStr = [checkboxParamStr stringByAppendingString: @"A"];
    if ([[properties objectForKey: @"Secure"] boolValue])
        checkboxParamStr = [checkboxParamStr stringByAppendingString: @"S"];
    if ([[properties objectForKey: @"Droppable"] boolValue] && [[properties objectForKey: @"AcceptsFiles"] boolValue])
        checkboxParamStr = [checkboxParamStr stringByAppendingString: @"D"];
    if ([[properties objectForKey: @"Droppable"] boolValue] && [[properties objectForKey: @"AcceptsText"] boolValue])
        checkboxParamStr = [checkboxParamStr stringByAppendingString: @"F"];
    if ([[properties objectForKey: @"Droppable"] boolValue] && [[properties objectForKey: @"DeclareService"] boolValue])
        checkboxParamStr = [checkboxParamStr stringByAppendingString: @"N"];
    if ([[properties objectForKey: @"ShowInDock"] boolValue])
        checkboxParamStr = [checkboxParamStr stringByAppendingString: @"B"];
    if (![[properties objectForKey: @"RemainRunning"] boolValue])
        checkboxParamStr = [checkboxParamStr stringByAppendingString: @"R"];
    
    if ([checkboxParamStr length] != 0)
        checkboxParamStr = [NSString stringWithFormat: @"-%@ ", checkboxParamStr];
    
    if (![[properties objectForKey: @"Version"] isEqualToString: @"1.0"])
        versionString = [NSString stringWithFormat:@" -V '%@' ", [properties objectForKey: @"Version"]];
    
    if (![[properties objectForKey: @"Author"] isEqualToString: NSFullUserName()])
        authorString = [NSString stringWithFormat: @" -u '%@' ", [properties objectForKey: @"Author"]];
    
    // if it's droppable, we need the Types and Suffixes
    if ([[properties objectForKey: @"Droppable"] boolValue])
    {
        //create suffixes param
        suffixesString = [[properties objectForKey: @"Suffixes"] componentsJoinedByString:@"|"];
        suffixesString = [NSString stringWithFormat: @"-X '%@' ", suffixesString];
        
        //create filetype codes param
        filetypesString = [[properties objectForKey: @"FileTypes"] componentsJoinedByString:@"|"];
        filetypesString = [NSString stringWithFormat: @"-T '%@' ", filetypesString];
    }
    
    //create bundled files string
    NSString *bundledFilesCmdString = @"";
    NSArray *bundledFiles = (NSArray *)[properties objectForKey: @"BundledFiles"];
    for (i = 0; i < [bundledFiles count]; i++)
    {
        bundledFilesCmdString = [bundledFilesCmdString stringByAppendingString: [NSString stringWithFormat: @"-f '%@' ", [bundledFiles objectAtIndex: i]]];
    }
    
    // create interpreter and script args flags
    if ([(NSArray *)[properties objectForKey: @"InterpreterArgs"] count])
    {
        NSString *arg = [[properties objectForKey: @"InterpreterArgs"] componentsJoinedByString:@"|"];
        parametersString = [parametersString stringByAppendingString: [NSString stringWithFormat: @"-G '%@' ", arg]];
    }
    if ([(NSArray *)[properties objectForKey: @"ScriptArgs"] count])
    {
        NSString *arg = [[properties objectForKey: @"ScriptArgs"] componentsJoinedByString:@"|"];
        parametersString = [parametersString stringByAppendingString: [NSString stringWithFormat: @"-C '%@' ", arg]];
    }
    
    //  create args for text settings if progress bar/text window or status menu
    if (([[properties objectForKey: @"Output"] isEqualToString: @"Text Window"] || 
         [[properties objectForKey: @"Output"] isEqualToString: @"Progress Bar"] ||
         [[properties objectForKey: @"Output"] isEqualToString: @"Status Menu"]))
    {
        NSString *textFgString = @"", *textBgString = @"", *textFontString = @""; 
        if (![[properties objectForKey: @"TextForeground"] isEqualToString: DEFAULT_OUTPUT_FG_COLOR])
            textFgString = [NSString stringWithFormat: @" -g '%@' ", [properties objectForKey: @"TextForeground"]];
        
        if (![[properties objectForKey: @"TextBackground"] isEqualToString: DEFAULT_OUTPUT_BG_COLOR])
            textBgString = [NSString stringWithFormat: @" -b '%@' ", [properties objectForKey: @"TextForeground"]];
        
        if ([[properties objectForKey: @"TextSize"] floatValue] != DEFAULT_OUTPUT_FONTSIZE ||
            ![[properties objectForKey: @"TextFont"] isEqualToString: DEFAULT_OUTPUT_FONT])
            textFontString = [NSString stringWithFormat: @" -n '%@ %2.f' ", [properties objectForKey: @"TextFont"], [[properties objectForKey: @"TextSize"] floatValue]];
    
        textOutputString = [NSString stringWithFormat: @"%@%@%@", textFgString, textBgString, textFontString];
    }
    
    //    text encoding    
    if ([[properties objectForKey: @"TextEncoding"] intValue] != DEFAULT_OUTPUT_TXT_ENCODING)
        textEncodingString = [NSString stringWithFormat: @" -E %d ", [[properties objectForKey: @"TextEncoding"] intValue]];
    
    //create custom icon string
    if (![[properties objectForKey: @"IconPath"] isEqualToString: CMDLINE_ICON_PATH] && ![[properties objectForKey: @"IconPath"] isEqualToString: @""])
        iconParamStr = [NSString stringWithFormat: @" -i '%@' ", [properties objectForKey: @"IconPath"]];
    //create custom icon string
    if ([properties objectForKey: @"DocIcon"] && ![[properties objectForKey: @"DocIcon"] isEqualToString: @""])
        iconParamStr = [iconParamStr stringByAppendingFormat: @" -Q '%@' ", [properties objectForKey: @"DocIcon"]];
    
    //status menu settings, if output mode is status menu
    if ([[properties objectForKey: @"Output"] isEqualToString: @"Status Menu"])
    {
        // -K kind
        statusMenuOptionsString = [statusMenuOptionsString stringByAppendingString: [NSString stringWithFormat: @"-K '%@' ", [properties objectForKey: @"StatusItemDisplayType"]]];
        
        // -L /path/to/image
        if (![[properties objectForKey: @"StatusItemDisplayType"] isEqualToString: @"Text"])
            statusMenuOptionsString = [statusMenuOptionsString stringByAppendingString: @"-L '/path/to/image' "];
        
        // -Y 'Title'
        if (![[properties objectForKey: @"StatusItemDisplayType"] isEqualToString: @"Icon"])
            statusMenuOptionsString = [statusMenuOptionsString stringByAppendingString: [NSString stringWithFormat: @"-Y '%@' ", [properties objectForKey: @"StatusItemTitle"]]];
    }
    
    // only set app name arg if we have a proper value
    NSString *appNameArg = [[properties objectForKey: @"Name"] isEqualToString: @""] ? @"" : [NSString stringWithFormat: @" -a '%@'", [properties objectForKey: @"Name"]];
    
    // only add identifier argument if it varies from default
    NSString *identifArg = [NSString stringWithFormat: @" -I %@", [properties objectForKey: @"Identifier"]];
    if ([[properties objectForKey: @"Identifier"] isEqualToString: [PlatypusAppSpec standardBundleIdForAppName: [properties objectForKey: @"Name"] usingDefaults: NO]])
        identifArg = @"";
    
    // finally, generate the command
    NSString *commandStr = [NSString stringWithFormat: 
                            @"%@ %@%@%@ -o '%@' -p '%@'%@ %@%@%@%@%@%@%@%@%@ '%@'",
                            CMDLINE_TOOL_PATH,
                            checkboxParamStr,
                            iconParamStr,
                            appNameArg,
                            [properties objectForKey: @"Output"],
                            [properties objectForKey: @"Interpreter"],
                            authorString,
                            versionString,
                            identifArg,
                            suffixesString,
                            filetypesString,
                            bundledFilesCmdString,
                            parametersString,
                            textEncodingString,
                            textOutputString,
                            statusMenuOptionsString,
                            [properties objectForKey: @"ScriptPath"],
                            nil];
    
    return commandStr;
}
#else
- (instancetype)initWithDefaultsForScript:(NSString *)scriptPath {
    if (self = [self initWithDefaults]) {
        [self setDefaultsForScript:scriptPath];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [self initWithDefaults]) {
        [self addEntriesFromDictionary:dict];
        
        // Backwards compatibility, mapping old spec key names to new
        if (dict[AppSpecKey_InterpreterPath_Legacy]) {
            self[AppSpecKey_InterpreterPath] = dict[AppSpecKey_InterpreterPath_Legacy];
        }
        if (dict[AppSpecKey_InterfaceType_Legacy]) {
            self[AppSpecKey_InterfaceType] = dict[AppSpecKey_InterfaceType_Legacy];
        }
        if (dict[AppSpecKey_DocIconPath_Legacy]) {
            self[AppSpecKey_DocIconPath] = dict[AppSpecKey_DocIconPath_Legacy];
        }
        if (dict[AppSpecKey_RunInBackground_Legacy]) {
            self[AppSpecKey_RunInBackground] = dict[AppSpecKey_RunInBackground_Legacy];
        }        
    }
    return self;
}

- (instancetype)initWithProfile:(NSString *)profilePath {
    NSDictionary *profileDict = [NSDictionary dictionaryWithContentsOfFile:profilePath];
    if (profileDict == nil) {
        return nil;
    }
    
    NSMutableDictionary *updatedDict = [profileDict mutableCopy];
    NSString *basePath = [profilePath stringByDeletingLastPathComponent];
    
    // Find all non-absolute paths and resolve them
    // relative to the profile's containing folder
    for (NSString *key in profileDict) {
        
        // Keys ending with "Path", e.g. "InterpreterPath"
        if ([key hasSuffix:@"Path"] && ![profileDict[key] isEqualToString:@""]
            && [profileDict[key] isAbsolutePath] == NO) {
            NSString *absPath = [NSString stringWithFormat:@"%@/%@", basePath, profileDict[key]];
            updatedDict[key] = [absPath stringByStandardizingPath];
        }
        
        // Bundled files
        if ([key isEqualToString:AppSpecKey_BundledFiles]) {
            NSArray <NSString *> *paths = profileDict[key];
            updatedDict[key] = [NSMutableArray array];
            for (NSString *path in paths) {
                NSString *absPath = path;
                if ([path isAbsolutePath] == NO) {
                    absPath = [NSString stringWithFormat:@"%@/%@", basePath, path];
                }
                [updatedDict[key] addObject:absPath];
            }
        }
    }
    
    return [self initWithDictionary:(NSDictionary *)updatedDict];
}

+ (instancetype)specWithDefaults {
    return [[self alloc] initWithDefaults];
}

+ (instancetype)specWithDictionary:(NSDictionary *)dict {
    return [[self alloc] initWithDictionary:dict];
}

+ (instancetype)specWithProfile:(NSString *)profilePath {
    return [[self alloc] initWithProfile:profilePath];
}

+ (instancetype)specWithDefaultsFromScript:(NSString *)scriptPath {
    return [[self alloc] initWithDefaultsForScript:scriptPath];
}

#pragma mark - Set default values

- (void)setDefaults {
    self[AppSpecKey_Creator] = PROGRAM_CREATOR_STAMP;
    
    self[AppSpecKey_ExecutablePath] = CMDLINE_SCRIPT_EXEC_PATH;
    self[AppSpecKey_NibPath] = CMDLINE_NIB_PATH;
    self[AppSpecKey_DestinationPath] = DEFAULT_DESTINATION_PATH;
    self[AppSpecKey_Overwrite] = @NO;
    self[AppSpecKey_SymlinkFiles] = @NO;
    self[AppSpecKey_StripNib] = @YES;
    
    self[AppSpecKey_Name] = DEFAULT_APP_NAME;
    self[AppSpecKey_ScriptPath] = @"";
    self[AppSpecKey_InterfaceType] = DEFAULT_INTERFACE_TYPE_STRING;
    self[AppSpecKey_IconPath] = CMDLINE_ICON_PATH;
    
    self[AppSpecKey_InterpreterPath] = DEFAULT_INTERPRETER_PATH;
    self[AppSpecKey_InterpreterArgs] = @[];
    self[AppSpecKey_ScriptArgs] = @[];
    self[AppSpecKey_Version] = DEFAULT_VERSION;
    self[AppSpecKey_Identifier] = [PlatypusAppSpec bundleIdentifierForAppName:nil
                                                                   authorName:nil
                                                                usingDefaults:YES];
    
    NSString *defaultsAuthor = [DEFAULTS stringForKey:DefaultsKey_DefaultAuthor];
    self[AppSpecKey_Author] = defaultsAuthor ? defaultsAuthor : NSFullUserName();;
    
    self[AppSpecKey_Droppable] = @NO;
    self[AppSpecKey_Authenticate] = @NO;
    self[AppSpecKey_RemainRunning] = @YES;
    self[AppSpecKey_RunInBackground] = @NO;
    
    self[AppSpecKey_BundledFiles] = [NSMutableArray array];
    
    // File/drag acceptance properties
    self[AppSpecKey_Suffixes] = DEFAULT_SUFFIXES;
    self[AppSpecKey_Utis] = DEFAULT_UTIS;
    self[AppSpecKey_URISchemes] = DEFAULT_URI_PROTOCOLS;
    self[AppSpecKey_AcceptText] = @NO;
    self[AppSpecKey_AcceptFiles] = @NO;
    self[AppSpecKey_Service] = @NO;
    self[AppSpecKey_PromptForFile] = @NO;
    self[AppSpecKey_DocIconPath] = @"";
    
    // Text window settings
    self[AppSpecKey_TextFont] = DEFAULT_TEXT_FONT_NAME;
    self[AppSpecKey_TextSize] = @(DEFAULT_TEXT_FONT_SIZE);
    self[AppSpecKey_TextColor] = DEFAULT_TEXT_FG_COLOR;
    self[AppSpecKey_TextBackgroundColor] = DEFAULT_TEXT_BG_COLOR;
    
    // Status item settings
    self[AppSpecKey_StatusItemDisplayType] = PLATYPUS_STATUSITEM_DISPLAY_TYPE_DEFAULT;
    self[AppSpecKey_StatusItemTitle] = DEFAULT_STATUS_ITEM_TITLE;
    self[AppSpecKey_StatusItemIcon] = [NSData data];
    self[AppSpecKey_StatusItemUseSysfont] = @YES;
    self[AppSpecKey_StatusItemIconIsTemplate] = @NO;
}

/********************************************************
 Init with default values and then analyse script, then
 load default values based on analysed script properties
 ********************************************************/

- (void)setDefaultsForScript:(NSString *)scriptPath {
    // Start with a dict populated with defaults
    [self setDefaults];
    
    // Set script path
    self[AppSpecKey_ScriptPath] = scriptPath;
    
    // Determine app name based on script filename
    self[AppSpecKey_Name] = [PlatypusScriptUtils appNameFromScriptFile:scriptPath];
    
    // Find an interpreter for it
    NSString *interpreterPath = [PlatypusScriptUtils determineInterpreterPathForScriptFile:scriptPath];
    if (interpreterPath == nil || [interpreterPath isEqualToString:@""]) {
        interpreterPath = DEFAULT_INTERPRETER_PATH;
    } else {
        // Get args for interpreter
        NSMutableArray *shebangCmdComponents = [NSMutableArray arrayWithArray:[PlatypusScriptUtils parseInterpreterInScriptFile:scriptPath]];
        [shebangCmdComponents removeObjectAtIndex:0];
        self[AppSpecKey_InterpreterArgs] = shebangCmdComponents;
    }
    self[AppSpecKey_InterpreterPath] = interpreterPath;
    self[AppSpecKey_InterpreterArgs] = [PlatypusScriptUtils interpreterArgsForInterpreterPath:interpreterPath];
    self[AppSpecKey_ScriptArgs] = [PlatypusScriptUtils scriptArgsForInterpreterPath:interpreterPath];
    
    // Find parent folder wherefrom we create destination path of app bundle
    NSString *parentFolder = [scriptPath stringByDeletingLastPathComponent];
    NSString *destPath = [NSString stringWithFormat:@"%@/%@.app", parentFolder, self[AppSpecKey_Name]];
    self[AppSpecKey_DestinationPath] = destPath;
    self[AppSpecKey_Identifier] = [PlatypusAppSpec bundleIdentifierForAppName:self[AppSpecKey_Name]
                                                                   authorName:nil
                                                                usingDefaults:YES];
}

#pragma mark -

// Create app bundle based on spec data
- (BOOL)create {
    
    // Check if app already exists
    if ([FILEMGR fileExistsAtPath:self[AppSpecKey_DestinationPath]]) {
        if ([self[AppSpecKey_Overwrite] boolValue] == FALSE) {
            _error = [NSString stringWithFormat:@"App already exists at path %@. Use -y flag to overwrite.", self[AppSpecKey_DestinationPath]];
            return FALSE;
        }
        [self report:@"Overwriting app at path %@", self[AppSpecKey_DestinationPath]];
    }
    
    // Check if executable exists
    NSString *execSrcPath = self[AppSpecKey_ExecutablePath];
    if (![FILEMGR fileExistsAtPath:execSrcPath] || ![FILEMGR isReadableFileAtPath:execSrcPath]) {
        [self report:@"Executable %@ does not exist. Aborting.", execSrcPath];
        return NO;
    }
    
    // Check if source nib exists
    NSString *nibPath = self[AppSpecKey_NibPath];
    if (![FILEMGR fileExistsAtPath:nibPath] || ![FILEMGR isReadableFileAtPath:nibPath]) {
        [self report:@"Nib file %@ does not exist. Aborting.", nibPath];
        return NO;
    }
    
    [self report:@"Creating application bundle folder hierarchy"];
    
    // .app bundle
    // Get temporary directory, make sure it's kosher. Apparently NSTemporaryDirectory() can return nil
    // See http://www.cocoadev.com/index.pl?NSTemporaryDirectory
    NSString *tmpPath = NSTemporaryDirectory();
    if (tmpPath == nil) {
        tmpPath = @"/tmp/"; // Fallback, just in case
    }
    
    // Make sure we can write to temp path
    if ([FILEMGR isWritableFileAtPath:tmpPath] == NO) {
        _error = [NSString stringWithFormat:@"Could not write to the temp directory '%@'.", tmpPath];
        return FALSE;
    }
    
    // .app
    tmpPath = [tmpPath stringByAppendingString:[self[AppSpecKey_DestinationPath] lastPathComponent]];
    [FILEMGR createDirectoryAtPath:tmpPath withIntermediateDirectories:NO attributes:nil error:nil];
    
    // .app/Contents
    NSString *contentsPath = [tmpPath stringByAppendingString:@"/Contents"];
    [FILEMGR createDirectoryAtPath:contentsPath withIntermediateDirectories:NO attributes:nil error:nil];
    
    // .app/Contents/MacOS
    NSString *macosPath = [contentsPath stringByAppendingString:@"/MacOS"];
    [FILEMGR createDirectoryAtPath:macosPath withIntermediateDirectories:NO attributes:nil error:nil];
    
    // .app/Contents/Resources
    NSString *resourcesPath = [contentsPath stringByAppendingString:@"/Resources"];
    [FILEMGR createDirectoryAtPath:resourcesPath withIntermediateDirectories:NO attributes:nil error:nil];
    
    [self report:@"Copying executable to bundle"];
    
    // Copy exec file
    // .app/Contents/Resources/MacOS/ScriptExec
    NSString *outFolder = [macosPath stringByAppendingString:@"/"];
    NSString *execDestPath = [outFolder stringByAppendingString:self[AppSpecKey_Name]];
    if ([execSrcPath hasSuffix:GZIP_SUFFIX]) {
        // Create empty file
        [FILEMGR createFileAtPath:execDestPath contents:nil attributes:nil];
        NSFileHandle *outFile = [NSFileHandle fileHandleForWritingAtPath:execDestPath];
        // Extract gzip destination folder
        // gunzip -c ScriptExec.gz > filehandle
        NSTask *gunzipTask = [[NSTask alloc] init];
        [gunzipTask setLaunchPath:@"/usr/bin/gunzip"];
        [gunzipTask setArguments:@[@"-c", execSrcPath]];
        [gunzipTask setStandardOutput:outFile];
        [gunzipTask launch];
        [gunzipTask waitUntilExit];
    } else {
        [FILEMGR copyItemAtPath:execSrcPath toPath:execDestPath error:nil];
    }
    NSDictionary *execAttrDict = @{ NSFilePosixPermissions:[NSNumber numberWithShort:0777] };
    [FILEMGR setAttributes:execAttrDict ofItemAtPath:execDestPath error:nil];
    
    // Copy nib file to app bundle
    // .app/Contents/Resources/MainMenu.nib
    [self report:@"Copying nib file to bundle"];
    NSString *nibDestinationPath = [resourcesPath stringByAppendingString:@"/MainMenu.nib"];
    [FILEMGR copyItemAtPath:nibPath toPath:nibDestinationPath error:nil];
    
    if ([self[AppSpecKey_StripNib] boolValue] == YES && [FILEMGR fileExistsAtPath:IBTOOL_PATH]) {
        [self report:@"Optimizing nib file"];
        [PlatypusAppSpec optimizeNibFile:nibDestinationPath];
    }
    
    // Create script file in app bundle
    // .app/Contents/Resources/script
    [self report:@"Copying script to bundle"];
    
    NSString *scriptFilePath = [resourcesPath stringByAppendingString:@"/script"];
    
    if ([self[AppSpecKey_SymlinkFiles] boolValue] == YES) {
        [FILEMGR createSymbolicLinkAtPath:scriptFilePath
                      withDestinationPath:self[AppSpecKey_ScriptPath]
                                    error:nil];
    } else {
        // Copy script over
        [FILEMGR copyItemAtPath:self[AppSpecKey_ScriptPath] toPath:scriptFilePath error:nil];
    }
    
    NSDictionary *fileAttrDict = @{NSFilePosixPermissions: @0755UL};
    [FILEMGR setAttributes:fileAttrDict ofItemAtPath:scriptFilePath error:nil];
    
    // Create AppSettings property list in binary format
    // .app/Contents/Resources/AppSettings.plist
    [self report:@"Writing AppSettings.plist"];
    NSMutableDictionary *appSettingsPlist = [self appSettingsPlist];
    NSString *appSettingsPlistPath = [resourcesPath stringByAppendingString:@"/AppSettings.plist"];
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:appSettingsPlist
                                                                   format:NSPropertyListBinaryFormat_v1_0
                                                                  options:0
                                                                    error:nil];
    [plistData writeToFile:appSettingsPlistPath atomically:YES];
    
    // Create icon
    // .app/Contents/Resources/appIcon.icns
    if (self[AppSpecKey_IconPath]) {
        if ([FILEMGR fileExistsAtPath:self[AppSpecKey_IconPath]]) {
            [self report:@"Writing application icon"];
            NSString *iconPath = [resourcesPath stringByAppendingString:@"/AppIcon.icns"];
            [FILEMGR copyItemAtPath:self[AppSpecKey_IconPath] toPath:iconPath error:nil];
        } else {
            [self report:@"No icon at path %@", self[AppSpecKey_IconPath]];
        }
    }
    
    // Create document icon
    // .app/Contents/Resources/docIcon.icns
    if (self[AppSpecKey_DocIconPath] && ![self[AppSpecKey_DocIconPath] isEqualToString:@""]) {
        [self report:@"Writing document icon"];
        NSString *docIconPath = [resourcesPath stringByAppendingString:@"/docIcon.icns"];
        [FILEMGR copyItemAtPath:self[AppSpecKey_DocIconPath] toPath:docIconPath error:nil];
    }
    
    // Create Info.plist file in binary format
    // .app/Contents/Info.plist
    [self report:@"Writing Info.plist"];
    NSDictionary *infoPlist = [self infoPlist];
    NSString *infoPlistPath = [contentsPath stringByAppendingString:@"/Info.plist"];
    NSData *infoData = [NSPropertyListSerialization dataWithPropertyList:infoPlist
                                                                  format:NSPropertyListBinaryFormat_v1_0
                                                                 options:0
                                                                   error:nil];
    if (!infoData || ![infoData writeToFile:infoPlistPath atomically:YES]) {
        _error = @"Error writing Info.plist";
        return FALSE;
    }
    
    // Copy bundled files to Resources folder
    // .app/Contents/Resources/*
    NSInteger numBundledFiles = [self[AppSpecKey_BundledFiles] count];
    if (numBundledFiles) {
        [self report:@"Copying %d bundled files", numBundledFiles];
    }
    for (id bundledFile in self[AppSpecKey_BundledFiles]) {
        
        // Check if it's an embedded file or a path string
        NSString *bundledFilePath;
        if ([bundledFile isKindOfClass:[NSDictionary class]]) {
            
            // Bundled files can be embedded in Platypus Profiles
            // If an entry in the array is a dictionary with a "Name"
            // and "Data" key, we create a file in a tmp directory
            // and then use its path
            NSDictionary *bundledFileDict = (NSDictionary *)bundledFile;
            NSString *name = bundledFileDict[@"Name"];
            NSData *data = bundledFileDict[@"Data"];
            if (!name || !data) {
                continue;
            }
            NSString *path = [FILEMGR createTempFileNamed:name withContents:@""];
            if (path) {
                [data writeToFile:path atomically:NO];
            } else {
                NSLog(@"Warning: Could not create tmp file named '%@'", name);
            }
        } else if ([bundledFile isKindOfClass:[NSString class]]) {
            bundledFilePath = (NSString *)bundledFile;
        } else {
            continue;
        }
        
        NSString *fileName = [bundledFilePath lastPathComponent];
        NSString *bundledFileDestPath = [resourcesPath stringByAppendingString:@"/"];
        bundledFileDestPath = [bundledFileDestPath stringByAppendingString:fileName];
        
        // If it's a development version, we just symlink it
        if ([self[AppSpecKey_SymlinkFiles] boolValue]) {
            [self report:@"Symlinking to \"%@\" in bundle", fileName];
            [FILEMGR createSymbolicLinkAtPath:bundledFileDestPath withDestinationPath:bundledFilePath error:nil];
        } else {
            [self report:@"Copying '%@' to bundle", fileName];
            
            // Otherwise we copy it
            // First remove any file in destination path
            // NB: This means any previously copied files are overwritten
            // and so users can bundle in their own MainMenu.nib etc.
            if ([FILEMGR fileExistsAtPath:bundledFileDestPath]) {
                [FILEMGR removeItemAtPath:bundledFileDestPath error:nil];
            }
            if ([FILEMGR fileExistsAtPath:bundledFilePath]) {
                [FILEMGR copyItemAtPath:bundledFilePath toPath:bundledFileDestPath error:nil];
            } else {
                [self report:@"Bundled file '%@' does not exist, skipping.", fileName];
            }
        }
    }
    
    // Sign app if signing identity has been provided
    if (self[AppSpecKey_SigningIdentity]) {
        [self report:@"Signing '%@'", [tmpPath lastPathComponent]];
        int err = [PlatypusAppSpec signApp:tmpPath usingIdentity:self[AppSpecKey_SigningIdentity]];
        if (err) {
            [self report:@"Failed to sign app. codesign err %d", err];
        }
    }
    
    // COPY APP OVER TO FINAL DESTINATION
    // We've created the application bundle in the temporary directory
    // now it's time to move it to the destination specified by the user
    [self report:@"Moving app to destination '%@'", self[AppSpecKey_DestinationPath]];
    
    NSString *destPath = self[AppSpecKey_DestinationPath];
    
    // First, let's see if there's anything there.  If we have overwrite set, we just delete that stuff
    if ([FILEMGR fileExistsAtPath:destPath]) {
        if ([self[AppSpecKey_Overwrite] boolValue]) {
            BOOL removed = [FILEMGR removeItemAtPath:destPath error:nil];
            if (!removed) {
                _error = [NSString stringWithFormat:@"Could not remove pre-existing item at path '%@'", destPath];
                return FALSE;
            }
        } else {
            _error = [NSString stringWithFormat:@"File already exists at path '%@'", destPath];
            return FALSE;
        }
    }
    
    // Now, move the newly created app to the destination
    [FILEMGR moveItemAtPath:tmpPath toPath:destPath error:nil];
    
    // If move wasn't a success, clean up app in tmp dir
    if (![FILEMGR fileExistsAtPath:destPath]) {
        [FILEMGR removeItemAtPath:tmpPath error:nil];
        _error = @"Failed to create application at the specified destination";
        return FALSE;
    }
    
    // Register app with macOS Launch Services to update its database
    [self report:@"Registering app with Launch Services"];
    [WORKSPACE registerAppWithLaunchServices:destPath];
    
    [self report:@"Done"];
    
    return TRUE;
}

// Generate AppSettings.plist dictionary
- (NSMutableDictionary *)appSettingsPlist {
    
    NSMutableDictionary *appSettingsPlist = [NSMutableDictionary dictionary];
    
    NSMutableArray *keys = [@[AppSpecKey_Authenticate,
                              AppSpecKey_Creator,
                              AppSpecKey_RemainRunning,
                              AppSpecKey_InterfaceType,
                              AppSpecKey_InterpreterPath,
                              AppSpecKey_InterpreterArgs,
                              AppSpecKey_ScriptArgs,
                              AppSpecKey_TextFont,
                              AppSpecKey_TextSize,
                              AppSpecKey_TextColor,
                              AppSpecKey_TextBackgroundColor,
                              AppSpecKey_Droppable,
                              AppSpecKey_AcceptFiles,
                              AppSpecKey_AcceptText,
                              AppSpecKey_PromptForFile,
                              AppSpecKey_Suffixes,
                              AppSpecKey_Utis,
                              AppSpecKey_URISchemes] mutableCopy];
    
    // Status menu info
    if (InterfaceTypeForString(self[AppSpecKey_InterfaceType]) == PlatypusInterfaceType_StatusMenu) {
        NSArray *statusMenuKeys = @[AppSpecKey_StatusItemDisplayType,
                                    AppSpecKey_StatusItemTitle,
                                    AppSpecKey_StatusItemIcon,
                                    AppSpecKey_StatusItemUseSysfont,
                                    AppSpecKey_StatusItemIconIsTemplate];
        [keys addObjectsFromArray:statusMenuKeys];
    }
    
    // Map keys from self to plist
    for (NSString *k in keys) {
        appSettingsPlist[k] = self[k];
    }
    
    appSettingsPlist[AppSpecKey_Creator] = PROGRAM_CREATOR_STAMP;

    return appSettingsPlist;
}

// Generate Info.plist dictionary
- (NSDictionary *)infoPlist {
    
    // Create copyright string with current year
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy"];
    NSString *yearString = [formatter stringFromDate:[NSDate date]];
    NSString *copyrightString = [NSString stringWithFormat:@"© %@ %@", yearString, self[AppSpecKey_Author]];
    
    // Create dict
    NSMutableDictionary *infoPlist = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        @"en",                                  @"CFBundleDevelopmentRegion",
        self[AppSpecKey_Name],                  @"CFBundleExecutable",
        self[AppSpecKey_Name],                  @"CFBundleName",
        self[AppSpecKey_Name],                  @"CFBundleDisplayName",
        copyrightString,                        @"NSHumanReadableCopyright",
        self[AppSpecKey_Version],               @"CFBundleShortVersionString",
        self[AppSpecKey_Identifier],            @"CFBundleIdentifier",
        self[AppSpecKey_RunInBackground],       @"LSUIElement",
        @"6.0",                                 @"CFBundleInfoDictionaryVersion",
        @"MainMenu",                            @"NSMainNibFile",
        @"APPL",                                @"CFBundlePackageType",
        PROGRAM_MIN_SYS_VERSION,                @"LSMinimumSystemVersion",
        @"NSApplication",                       @"NSPrincipalClass",
        @{@"NSAllowsArbitraryLoads": @YES},     @"NSAppTransportSecurity",
    nil];
    
    // Add icon name if icon is set
    if (self[AppSpecKey_IconPath] && [FILEMGR fileExistsAtPath:self[AppSpecKey_IconPath]]) {
        infoPlist[@"CFBundleIconFile"] = @"AppIcon.icns";
    }
    
    // If droppable, we declare the accepted file types
    if ([self[AppSpecKey_Droppable] boolValue]) {
        
        NSMutableDictionary *typesAndSuffixesDict = [NSMutableDictionary dictionary];
        
        typesAndSuffixesDict[@"CFBundleTypeExtensions"] = self[AppSpecKey_Suffixes];
        typesAndSuffixesDict[@"CFBundleTypeRole"] = @"Viewer";
        
        if (self[AppSpecKey_Utis] != nil && [self[AppSpecKey_Utis] count] > 0) {
            typesAndSuffixesDict[@"LSItemContentTypes"] = self[AppSpecKey_Utis];
        }
        
        // Document icon
        if (self[AppSpecKey_DocIconPath] && [FILEMGR fileExistsAtPath:self[AppSpecKey_DocIconPath]]) {
            typesAndSuffixesDict[@"CFBundleTypeIconFile"] = @"docIcon.icns";
        }
        
        // Set file types and suffixes
        infoPlist[@"CFBundleDocumentTypes"] = @[typesAndSuffixesDict];
        
        // Add service settings to Info.plist
        if ([self[AppSpecKey_Service] boolValue]) {
            
            NSMutableDictionary *serviceDict = [NSMutableDictionary dictionary];
            
            serviceDict[@"NSMenuItem"] = @{@"default": [NSString stringWithFormat:@"Process with %@", self[AppSpecKey_Name]]};
            serviceDict[@"NSMessage"] = @"dropService";
            serviceDict[@"NSPortName"] = self[AppSpecKey_Name];
            serviceDict[@"NSTimeout"] = @(3000);
            
            // Service data type handling
            NSMutableArray *sendTypes = [NSMutableArray array];
            if ([self[AppSpecKey_AcceptFiles] boolValue]) {
                [sendTypes addObject:@"NSFilenamesPboardType"];
                serviceDict[@"NSSendFileTypes"] = @[(NSString *)kUTTypeItem];
            }
            if ([self[AppSpecKey_AcceptText] boolValue]) {
                [sendTypes addObject:@"NSStringPboardType"];
            }
            serviceDict[@"NSSendTypes"] = sendTypes;

#if 0
            serviceDict[@"NSSendFileTypes"] = @[];
            serviceDict[@"NSServiceDescription"]
#endif
            
            infoPlist[@"NSServices"] = @[serviceDict];
        }
    }
    
    // If any URI protocol handling
    if (self[AppSpecKey_URISchemes] && [self[AppSpecKey_URISchemes] count]) {
        
        NSDictionary *dict = @{ @"CFBundleURLName": self[AppSpecKey_Name],
                                @"CFBundleURLSchemes": self[AppSpecKey_URISchemes] };
        
        infoPlist[@"CFBundleURLTypes"] = @[dict];
    }
    
    return infoPlist;
}

- (void)report:(NSString *)format, ... {
    if ([self silentMode]) {
        return;
    }
    
    va_list args;
    
    va_start(args, format);
    NSString *string  = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    fprintf(stderr, "%s\n", [string UTF8String]);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PLATYPUS_APP_SPEC_CREATION_NOTIFICATION object:string];
}

// Check spec for basic sanity
- (BOOL)verify {
    
    if ([self[AppSpecKey_DestinationPath] hasSuffix:APPBUNDLE_SUFFIX] == FALSE) {
        _error = @"Destination must end with .app";
        return NO;
    }
    
    if ([NSFont fontWithName:self[AppSpecKey_TextFont] size:13] == nil) {
        [self report:@"Warning: Font \"%@\" cannot be instantiated.", self[AppSpecKey_TextFont]];
    }
    
    if ([self[AppSpecKey_Name] isEqualToString:@""]) {
        _error = @"Empty app name";
        return NO;
    }
    
    BOOL isDir;
    if (![FILEMGR fileExistsAtPath:self[AppSpecKey_ScriptPath] isDirectory:&isDir] || isDir) {
        _error = [NSString stringWithFormat:@"Script not found at path '%@'", self[AppSpecKey_ScriptPath], nil];
        return NO;
    }
    
    if (![FILEMGR fileExistsAtPath:self[AppSpecKey_ExecutablePath] isDirectory:&isDir] || isDir) {
        _error = [NSString stringWithFormat:@"Executable binary not found at path '%@'", self[AppSpecKey_ExecutablePath], nil];
        return NO;
    }
    
    if (![FILEMGR fileExistsAtPath:self[AppSpecKey_NibPath]]) {
        _error = [NSString stringWithFormat:@"Nib not found at path '%@'", self[AppSpecKey_NibPath], nil];
        return NO;
    }
    
    if (![FILEMGR fileExistsAtPath:[self[AppSpecKey_DestinationPath] stringByDeletingLastPathComponent] isDirectory:&isDir] || !isDir) {
        _error = [NSString stringWithFormat:@"Destination directory '%@' does not exist.", [self[AppSpecKey_DestinationPath] stringByDeletingLastPathComponent], nil];
        return NO;
    }
    
    if (![FILEMGR isWritableFileAtPath:[self[AppSpecKey_DestinationPath] stringByDeletingLastPathComponent]]) {
        _error = [NSString stringWithFormat:@"Don't have permission to write to the destination directory '%@'", self[AppSpecKey_DestinationPath]];
        return NO;
    }
    
    for (NSString *path in self[AppSpecKey_BundledFiles]) {
        if (![FILEMGR fileExistsAtPath:path]) {
            _error = @"One or more bundled files no longer exist at the specified path.";
            return NO;
        }
    }
    
    return YES;
}
#endif

#pragma mark -

#ifdef PLATYPUS_HEAD
-(void)setProperty: (id)property forKey: (NSString *)theKey
{
    [properties setObject: property forKey: theKey];
}

-(id)propertyForKey: (NSString *)theKey
{
    return [properties objectForKey: theKey];
}

-(void)addProperties: (NSDictionary *)dict
{
    [properties addEntriesFromDictionary: dict];
}

-(NSDictionary *)properties
{
    return [properties retain];
}

-(NSString *)error
{
    return error;
}

-(NSString *)description
{
    return [properties description];
}

#pragma mark - Class Methods

/*****************************************
 - //return the bundle identifier for the application to be generated
 -  based on username etc. e.g. org.username.AppName
 *****************************************/

+ (NSString *)standardBundleIdForAppName: (NSString *)name  usingDefaults: (BOOL)def;
{
    NSString *defaults = def ? [DEFAULTS stringForKey:@"DefaultBundleIdentifierPrefix"] : @"";    
    
    NSString *pre = (!def || [defaults isEqualToString: @""]) ? [NSString stringWithFormat: @"org.%@.", NSUserName()] : defaults;
    
    NSString *bundleId = [NSString stringWithFormat: @"%@%@", pre , name];
    bundleId = [PlatypusUtility removeWhitespaceInString: bundleId];//no spaces
    
    return bundleId;
}
#else
- (void)writeToFile:(NSString *)filePath {
    [self writeToFile:filePath atomically:YES];
}

// Dump spec dictionary to stdout in XML plist format
- (void)dump {
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:self
                                                              format:NSPropertyListXMLFormat_v1_0
                                                             options:0
                                                               error:nil];
    [[NSFileHandle fileHandleWithStandardOutput] writeData:data];
}

#pragma mark - Command string generation

- (NSString *)commandStringUsingShortOpts:(BOOL)shortOpts {
    NSString *checkboxParamStr = @"";
    NSString *iconParamStr = @"";
    NSString *versionString = @"";
    NSString *authorString = @"";
    NSString *suffixesString = @"";
    NSString *uniformTypesString = @"";
    NSString *uriSchemesString = @"";
    NSString *parametersString = @"";
    NSString *textSettingsString = @"";
    NSString *statusMenuOptionsString = @"";
    
    if ([self[AppSpecKey_Authenticate] boolValue]) {
        NSString *str = shortOpts ? @"-A " : @"--admin-privileges ";
        checkboxParamStr = [checkboxParamStr stringByAppendingString:str];
    }
    
    if ([self[AppSpecKey_AcceptFiles] boolValue] && [self[AppSpecKey_Droppable] boolValue]) {
        NSString *str = shortOpts ? @"-D " : @"--droppable ";
        checkboxParamStr = [checkboxParamStr stringByAppendingString:str];
    }
    
    if ([self[AppSpecKey_AcceptText] boolValue] && [self[AppSpecKey_Droppable] boolValue]) {
        NSString *str = shortOpts ? @"-F " : @"--text-droppable ";
        checkboxParamStr = [checkboxParamStr stringByAppendingString:str];
    }
    
    if ([self[AppSpecKey_Service] boolValue] && [self[AppSpecKey_Droppable] boolValue]) {
        NSString *str = shortOpts ? @"-N " : @"--service ";
        checkboxParamStr = [checkboxParamStr stringByAppendingString:str];
    }
    
    if ([self[AppSpecKey_RunInBackground] boolValue]) {
        NSString *str = shortOpts ? @"-B " : @"--background ";
        checkboxParamStr = [checkboxParamStr stringByAppendingString:str];
    }
    
    if ([self[AppSpecKey_RemainRunning] boolValue] == FALSE) {
        NSString *str = shortOpts ? @"-R " : @"--quit-after-execution ";
        checkboxParamStr = [checkboxParamStr stringByAppendingString:str];
    }
    
    if ([self[AppSpecKey_Version] isEqualToString:DEFAULT_VERSION] == FALSE) {
        NSString *str = shortOpts ? @"-V" : @"--app-version";
        versionString = [NSString stringWithFormat:@" %@ '%@' ", str, self[AppSpecKey_Version]];
    }
    
    if (![self[AppSpecKey_Author] isEqualToString:NSFullUserName()]) {
        NSString *str = shortOpts ? @"-u" : @"--author";
        authorString = [NSString stringWithFormat:@" %@ '%@' ", str, self[AppSpecKey_Author]];
    }
    
    NSString *promptForFileString = @"";
    if ([self[AppSpecKey_Droppable] boolValue]) {
        //  Suffixes
        if ([self[AppSpecKey_Suffixes] count]) {
            NSString *str = shortOpts ? @"-X" : @"--suffixes";
            suffixesString = [self[AppSpecKey_Suffixes] componentsJoinedByString:CMDLINE_ARG_SEPARATOR];
            suffixesString = [NSString stringWithFormat:@"%@ '%@' ", str, suffixesString];
        }
        // UTIs
        if ([self[AppSpecKey_Utis] count]) {
            NSString *str = shortOpts ? @"-T" : @"--uniform-type-identifiers";
            uniformTypesString = [self[AppSpecKey_Utis] componentsJoinedByString:CMDLINE_ARG_SEPARATOR];
            uniformTypesString = [NSString stringWithFormat:@"%@ '%@' ", str, uniformTypesString];
        }
        // File prompt
        if ([self[AppSpecKey_PromptForFile] boolValue]) {
            NSString *str = shortOpts ? @"-Z" : @"--file-prompt";
            promptForFileString = [NSString stringWithFormat:@"%@ ", str];
        }
    }
    
    // Uniform type identifier params
    if ([self[AppSpecKey_URISchemes] count]) {
        NSString *str = shortOpts ? @"-U" : @"--uri-schemes";
        uriSchemesString = [self[AppSpecKey_URISchemes] componentsJoinedByString:CMDLINE_ARG_SEPARATOR];
        uriSchemesString = [NSString stringWithFormat:@"%@ '%@' ", str, uriSchemesString];
    }
    
    // Create bundled files string
    NSString *bundledFilesCmdString = @"";
    NSArray *bundledFiles = self[AppSpecKey_BundledFiles];
    for (int i = 0; i < [bundledFiles count]; i++) {
        NSString *str = shortOpts ? @"-f" : @"--bundled-file";
        bundledFilesCmdString = [bundledFilesCmdString stringByAppendingString:[NSString stringWithFormat:@"%@ '%@' ", str, bundledFiles[i]]];
    }
    
    // Create interpreter and script args flags
    if ([self[AppSpecKey_InterpreterArgs] count]) {
        NSString *str = shortOpts ? @"-G" : @"--interpreter-args";
        NSString *arg = [self[AppSpecKey_InterpreterArgs] componentsJoinedByString:CMDLINE_ARG_SEPARATOR];
        parametersString = [parametersString stringByAppendingString:[NSString stringWithFormat:@"%@ '%@' ", str, arg]];
    }
    if ([self[AppSpecKey_ScriptArgs] count]) {
        NSString *str = shortOpts ? @"-C" : @"--script-args";
        NSString *arg = [self[AppSpecKey_ScriptArgs] componentsJoinedByString:CMDLINE_ARG_SEPARATOR];
        parametersString = [parametersString stringByAppendingString:[NSString stringWithFormat:@"%@ '%@' ", str, arg]];
    }
    
    // Create args for text settings
    if (IsTextStyledInterfaceTypeString(self[AppSpecKey_InterfaceType])) {
        
        NSString *textFgString = @"", *textBgString = @"", *textFontString = @"";
        if (![self[AppSpecKey_TextColor] isEqualToString:DEFAULT_TEXT_FG_COLOR]) {
            NSString *str = shortOpts ? @"-g" : @"--text-foreground-color";
            textFgString = [NSString stringWithFormat:@" %@ '%@' ", str, self[AppSpecKey_TextColor]];
        }
        
        if (![self[AppSpecKey_TextBackgroundColor] isEqualToString:DEFAULT_TEXT_BG_COLOR]) {
            NSString *str = shortOpts ? @"-b" : @"--text-background-color";
            textBgString = [NSString stringWithFormat:@" %@ '%@' ", str, self[AppSpecKey_TextColor]];
        }
        
        if ([self[AppSpecKey_TextSize] floatValue] != DEFAULT_TEXT_FONT_SIZE ||
            ![self[AppSpecKey_TextFont] isEqualToString:DEFAULT_TEXT_FONT_NAME]) {
            NSString *str = shortOpts ? @"-n" : @"--text-font";
            textFontString = [NSString stringWithFormat:@" %@ '%@ %2.f' ", str, self[AppSpecKey_TextFont], [self[AppSpecKey_TextSize] floatValue]];
        }
        
        textSettingsString = [NSString stringWithFormat:@"%@%@%@", textFgString, textBgString, textFontString];
    }
    
    // Custom icon arg
    if (![self[AppSpecKey_IconPath] isEqualToString:CMDLINE_ICON_PATH] && ![self[AppSpecKey_IconPath] isEqualToString:@""]) {
        NSString *str = shortOpts ? @"-i" : @"--app-icon";
        iconParamStr = [NSString stringWithFormat:@"%@ '%@' ", str, self[AppSpecKey_IconPath]];
    }
    
    // Custom document icon arg
    if (self[AppSpecKey_DocIconPath] && ![self[AppSpecKey_DocIconPath] isEqualToString:@""]) {
        NSString *str = shortOpts ? @"-Q" : @"--document-icon";
        iconParamStr = [iconParamStr stringByAppendingFormat:@" %@ '%@' ", str, self[AppSpecKey_DocIconPath]];
    }
    
    // Status menu settings, if interface type is status menu
    if (InterfaceTypeForString(self[AppSpecKey_InterfaceType]) == PlatypusInterfaceType_StatusMenu) {
        // -K kind
        NSString *str = shortOpts ? @"-K" : @"--status-item-kind";
        statusMenuOptionsString = [statusMenuOptionsString stringByAppendingFormat:@"%@ '%@' ", str, self[AppSpecKey_StatusItemDisplayType]];
        
        // -L /path/to/image
        if ([self[AppSpecKey_StatusItemDisplayType] isEqualToString:PLATYPUS_STATUSITEM_DISPLAY_TYPE_ICON]) {
            str = shortOpts ? @"-L" : @"--status-item-icon";
            statusMenuOptionsString = [statusMenuOptionsString stringByAppendingFormat:@"%@ '/path/to/image' ", str];
        }
        
        // -Y 'Title'
        else if ([self[AppSpecKey_StatusItemDisplayType] isEqualToString:PLATYPUS_STATUSITEM_DISPLAY_TYPE_TEXT]) {
            str = shortOpts ? @"-Y" : @"--status-item-title";
            statusMenuOptionsString = [statusMenuOptionsString stringByAppendingFormat:@"%@ '%@' ", str, self[AppSpecKey_StatusItemTitle]];
        }
        
        // -c
        if ([self[AppSpecKey_StatusItemUseSysfont] boolValue]) {
            str = shortOpts ? @"-c" : @"--status-item-sysfont";
            statusMenuOptionsString = [statusMenuOptionsString stringByAppendingFormat:@"%@ ", str];
        }
        
        // -q
        if ([self[AppSpecKey_StatusItemIconIsTemplate] boolValue]) {
            str = shortOpts ? @"-q" : @"--status-item-template-icon";
            statusMenuOptionsString = [statusMenuOptionsString stringByAppendingFormat:@"%@ ", str];
        }
    }
    
    // Only set app name arg if we have a proper value
    NSString *appNameArg = @"";
    if ([self[AppSpecKey_Name] isEqualToString:@""] == FALSE) {
        NSString *str = shortOpts ? @"-a" : @"--name";
        appNameArg = [NSString stringWithFormat: @" %@ '%@' ", str,  self[AppSpecKey_Name]];
    }
    
    // Only add identifier argument if it varies from default
    NSString *identifierArg = @"";
    NSString *standardIdentifier = [PlatypusAppSpec bundleIdentifierForAppName:self[AppSpecKey_Name] authorName:nil usingDefaults: NO];
    if ([self[AppSpecKey_Identifier] isEqualToString:standardIdentifier] == FALSE) {
        NSString *str = shortOpts ? @"-I" : @"--bundle-identifier";
        identifierArg = [NSString stringWithFormat: @" %@ %@ ", str, self[AppSpecKey_Identifier]];
    }
    
    // Interface type
    NSString *str = shortOpts ? @"-o" : @"--interface-type";
    NSString *interfaceArg = [NSString stringWithFormat:@" %@ '%@' ", str, self[AppSpecKey_InterfaceType]];
    
    // Interpreter
    str = shortOpts ? @"-p" : @"--interpreter";
    NSString *interpreterArg = [NSString stringWithFormat:@" %@ '%@' ", str, self[AppSpecKey_InterpreterPath]];
    
    // Finally, generate the command
    NSString *commandStr = [NSString stringWithFormat:
                            @"%@ %@%@%@%@%@%@ %@%@%@%@%@%@%@%@%@%@ '%@'",
                            CMDLINE_TOOL_PATH,
                            checkboxParamStr,
                            iconParamStr,
                            appNameArg,
                            interfaceArg,
                            interpreterArg,
                            authorString,
                            versionString,
                            identifierArg,
                            suffixesString,
                            uniformTypesString,
                            uriSchemesString,
                            promptForFileString,
                            bundledFilesCmdString,
                            parametersString,
                            textSettingsString,
                            statusMenuOptionsString,
                            self[AppSpecKey_ScriptPath],
                            nil];
    
    return commandStr;
}

#pragma mark - Class Methods

// Generate bundle identifier for app
+ (NSString *)bundleIdentifierForAppName:(NSString *)name authorName:(NSString *)authorName usingDefaults:(BOOL)def {
    NSString *appName = name ? name : DEFAULT_APP_NAME;
    NSString *defaults = def ? [DEFAULTS stringForKey:DefaultsKey_BundleIdentifierPrefix] : nil;
    NSString *author = authorName ? [authorName stringByReplacingOccurrencesOfString:@" " withString:@""] : NSUserName();
    NSString *pre = (defaults == nil) ? [NSString stringWithFormat:@"org.%@.", author] : defaults;
    
    NSString *identifierString = [NSString stringWithFormat:@"%@%@", pre, appName];
    identifierString = [identifierString stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    NSData *asciiData = [identifierString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    identifierString = [[NSString alloc] initWithData:asciiData encoding:NSASCIIStringEncoding];

    return identifierString;
}

// Use ibtool to strip a given nib file.
// This makes the file uneditable in Interface Builder.
+ (void)optimizeNibFile:(NSString *)nibPath {
    NSTask *ibToolTask = [[NSTask alloc] init];
    [ibToolTask setLaunchPath:IBTOOL_PATH];
    [ibToolTask setArguments:@[@"--strip", nibPath, nibPath]];
    [ibToolTask launch];
    [ibToolTask waitUntilExit];
}

// Run code signing tool on an app or binary
+ (int)signApp:(NSString *)path usingIdentity:(NSString *)identity {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:CODESIGN_PATH];
    [task setArguments:@[@"-s", identity, path]];
    [task launch];
    [task waitUntilExit];
    
    return [task terminationStatus];
}

#endif

@end
