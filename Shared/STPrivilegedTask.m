/*
    STPrivilegedTask - NSTask-like wrapper around AuthorizationExecuteWithPrivileges
    Copyright (C) 2009-2020 Sveinbjorn Thordarson <sveinbjorn@sveinbjorn.org>

    BSD License
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
        notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
        notice, this list of conditions and the following disclaimer in the
        documentation and/or other materials provided with the distribution.
    * Neither the name of the copyright holder nor that of any other
        contributors may be used to endorse or promote products
        derived from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL  BE LIABLE FOR ANY
    DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
    ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "STPrivilegedTask.h"

#import <Security/Authorization.h>
#import <Security/AuthorizationTags.h>
#import <stdio.h>
#import <unistd.h>
#import <dlfcn.h>

#ifdef PLATYPUS_HEAD
@implementation STPrivilegedTask

- (id)init
{
    if ((self = [super init])) 
    {
        launchPath = [[NSString alloc] initWithString: @""];
        cwd = [[NSString alloc] initWithString: [[NSFileManager defaultManager] currentDirectoryPath]];
        arguments = [[NSArray alloc] init];
        isRunning = NO;
        outputFileHandle = NULL;
    }
    return self;
}

-(void)dealloc
{    
    [launchPath release];
    [arguments release];
    [cwd release];
    
    if (outputFileHandle != NULL)
        [outputFileHandle release];
    
    [super dealloc];
}

-(id)initWithLaunchPath: (NSString *)path arguments:  (NSArray *)args
{
    if ((self = [self initWithLaunchPath: path]))
    {
        [self setArguments: args];
    }
    return self;
}

-(id)initWithLaunchPath: (NSString *)path
{
    if ((self = [self init]))
    {
        [self setLaunchPath: path];
    }
    return self;
}
#else
// New error code denoting that AuthorizationExecuteWithPrivileges no longer exists
OSStatus const errAuthorizationFnNoLongerExists = -70001;

// Create fn pointer to AuthorizationExecuteWithPrivileges in case
// it doesn't exist in this version of MacOS
static OSStatus (*_AuthExecuteWithPrivsFn)(AuthorizationRef authorization, const char *pathToTool, AuthorizationFlags options,
                                           char * const *arguments, FILE **communicationsPipe) = NULL;
#endif


#ifdef PLATYPUS_HEAD
+(STPrivilegedTask *)launchedPrivilegedTaskWithLaunchPath:(NSString *)path arguments:(NSArray *)args
{
    STPrivilegedTask *task = [[[STPrivilegedTask alloc] initWithLaunchPath: path arguments: args] autorelease];
    [task launch];
    [task waitUntilExit];
    return task;
}

+(STPrivilegedTask *)launchedPrivilegedTaskWithLaunchPath:(NSString *)path
{
    STPrivilegedTask *task = [[[STPrivilegedTask alloc] initWithLaunchPath: path] autorelease];
    [task launch];
    [task waitUntilExit];
    return task;
}
#else
@implementation STPrivilegedTask
{
    NSTimer *_checkStatusTimer;
}
#endif

+ (void)initialize;
{
#ifdef PLATYPUS_HEAD
    return arguments;
#else
    // On 10.7, AuthorizationExecuteWithPrivileges is deprecated. We want
    // to still use it since there's no good alternative (without requiring
    // code signing). We'll look up the function through dyld and fail if
    // it is no longer accessible. If Apple removes the function entirely
    // this will fail gracefully. If they keep the function and throw some
    // sort of exception, this won't fail gracefully, but that's a risk
    // we'll have to take for now.
    // Pattern by Andy Kim from Potion Factory LLC
#pragma GCC diagnostic ignored "-Wpedantic" // stop the pedantry!
#pragma clang diagnostic push
    _AuthExecuteWithPrivsFn = dlsym(RTLD_DEFAULT, "AuthorizationExecuteWithPrivileges");
#pragma clang diagnostic pop
#endif
}

- (instancetype)init
{
#ifdef PLATYPUS_HEAD
    return cwd;
#else
    self = [super init];
    if (self) {
        _launchPath = nil;
        _arguments = nil;
        _isRunning = NO;
        _outputFileHandle = nil;
        _terminationHandler = nil;
        _currentDirectoryPath = [[NSFileManager defaultManager] currentDirectoryPath];
    }
    return self;
#endif
}

- (instancetype)initWithLaunchPath:(NSString *)path
{
#ifdef PLATYPUS_HEAD
    return isRunning;
#else
    self = [self init];
    if (self) {
        self.launchPath = path;
    }
    return self;
#endif
}

- (instancetype)initWithLaunchPath:(NSString *)path arguments:(NSArray *)args
{
#ifdef PLATYPUS_HEAD
    return launchPath;
#else
    self = [self initWithLaunchPath:path];
    if (self)  {
        self.arguments = args;
    }
    return self;
#endif
}

- (instancetype)initWithLaunchPath:(NSString *)path arguments:(NSArray *)args currentDirectory:(NSString *)cwd
{
#ifdef PLATYPUS_HEAD
    return pid;
#else
    self = [self initWithLaunchPath:path arguments:args];
    if (self) {
        self.currentDirectoryPath = cwd;
    }
    return self;
#endif
}

#ifdef PLATYPUS_HEAD
- (int)terminationStatus
{
    return terminationStatus;
}
#else
#pragma mark -
#endif

+ (STPrivilegedTask *)launchedPrivilegedTaskWithLaunchPath:(NSString *)path
{
#ifdef PLATYPUS_HEAD
    return outputFileHandle;
#else
    STPrivilegedTask *task = [[STPrivilegedTask alloc] initWithLaunchPath:path];
    [task launch];
    [task waitUntilExit];
    return task;
#endif
}

#ifdef PLATYPUS_HEAD
#pragma mark -

-(void)setArguments:(NSArray *)args
{
    [arguments release];
    arguments = [args retain];
}

-(void)setCurrentDirectoryPath:(NSString *)path
{
    [cwd release];
    cwd = [path retain];
}

-(void)setLaunchPath:(NSString *)path
{
    [launchPath release];
    launchPath = [path retain];
}
#else

+ (STPrivilegedTask *)launchedPrivilegedTaskWithLaunchPath:(NSString *)path arguments:(NSArray *)args
{
    STPrivilegedTask *task = [[STPrivilegedTask alloc] initWithLaunchPath:path arguments:args];
    [task launch];
    [task waitUntilExit];
    return task;
}

+ (STPrivilegedTask *)launchedPrivilegedTaskWithLaunchPath:(NSString *)path arguments:(NSArray *)args currentDirectory:(NSString *)cwd
{
    STPrivilegedTask *task = [[STPrivilegedTask alloc] initWithLaunchPath:path arguments:args currentDirectory:cwd];
    [task launch];
    [task waitUntilExit];
    return task;
}

+ (STPrivilegedTask *)launchedPrivilegedTaskWithLaunchPath:(NSString *)path arguments:(NSArray *)args currentDirectory:(NSString *)cwd authorization:(AuthorizationRef)authorization
{
    STPrivilegedTask *task = [[STPrivilegedTask alloc] initWithLaunchPath:path arguments:args currentDirectory:cwd];
    [task launchWithAuthorization:authorization];
    [task waitUntilExit];
    return task;
}
#endif

# pragma mark -

// return 0 for success
#ifdef PLATYPUS_HEAD
-(int) launch
{
    OSStatus                err = noErr;
    short                   i;
    const char              *toolPath = [launchPath fileSystemRepresentation];
    
    AuthorizationRef        authorizationRef;
    AuthorizationItem       myItems = {kAuthorizationRightExecute, strlen(toolPath), &toolPath, 0};
    AuthorizationRights     myRights = {1, &myItems};
    AuthorizationFlags      flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    
    unsigned int            argumentsCount = [arguments count];
    char                    *args[argumentsCount + 1];
    FILE                    *outputFile;

#else
- (OSStatus)launch
{
    if (_isRunning) {
        NSLog(@"Task already running: %@", [self description]);
        return 0;
    }
    
    if ([STPrivilegedTask authorizationFunctionAvailable] == NO) {
        NSLog(@"AuthorizationExecuteWithPrivileges() function not available on this system");
        return errAuthorizationFnNoLongerExists;
    }
    
    OSStatus err = noErr;
    const char *toolPath = [self.launchPath fileSystemRepresentation];
    
    AuthorizationRef authorizationRef;
    AuthorizationItem myItems = { kAuthorizationRightExecute, strlen(toolPath), &toolPath, 0 };
    AuthorizationRights myRights = { 1, &myItems };
    AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    
#endif
    // Use Apple's Authentication Manager APIs to get an Authorization Reference
    // These Apple APIs are quite possibly the most horrible of the Mac OS X APIs
    
    // create authorization reference
    err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
#ifdef PLATYPUS_HEAD
    if (err != errAuthorizationSuccess)
        return err;
    
    // pre-authorize the privileged operation
    err = AuthorizationCopyRights(authorizationRef, &myRights, kAuthorizationEmptyEnvironment, flags, NULL);
    if (err != errAuthorizationSuccess) 
        return err;
    
    // OK, at this point we have received authorization for the task.
    // Let's prepare to launch it
    
    // first, construct an array of c strings from NSArray w. arguments
    for (i = 0; i < argumentsCount; i++) 
    {
        NSString *theString = [arguments objectAtIndex:i];
        unsigned int stringLength = [theString length];
        
        args[i] = malloc((stringLength + 1) * sizeof(char));
        snprintf(args[i], stringLength + 1, "%s", [theString fileSystemRepresentation]);
    }
    args[argumentsCount] = NULL;
    
    // change to the current dir specified
    char *prevCwd = (char *)getcwd(nil, 0);
    chdir([cwd fileSystemRepresentation]);
    
    //use Authorization Reference to execute script with privileges
    err = AuthorizationExecuteWithPrivileges(authorizationRef, [launchPath fileSystemRepresentation], kAuthorizationFlagDefaults, args, &outputFile);
#else
    if (err != errAuthorizationSuccess) {
        return err;
    }
    
    // pre-authorize the privileged operation
    err = AuthorizationCopyRights(authorizationRef, &myRights, kAuthorizationEmptyEnvironment, flags, NULL);
    if (err != errAuthorizationSuccess) {
        return err;
    }
    
    // OK, at this point we have received authorization for the task.
    err = [self launchWithAuthorization:authorizationRef];
    
    // free the auth ref
    AuthorizationFree(authorizationRef, kAuthorizationFlagDefaults);
    
    return err;
}

- (OSStatus)launchWithAuthorization:(AuthorizationRef)authorization
{
    if (_isRunning) {
        NSLog(@"Task already running: %@", [self description]);
        return 0;
    }
    
    if ([STPrivilegedTask authorizationFunctionAvailable] == NO) {
        NSLog(@"AuthorizationExecuteWithPrivileges() function not available on this system");
        return errAuthorizationFnNoLongerExists;
    }
    
    // Assuming the authorization is valid for the task.
    // Let's prepare to launch it
    NSArray *arguments = self.arguments;
    NSUInteger numberOfArguments = [arguments count];
    char *args[numberOfArguments + 1];
    FILE *outputFile;
    
    const char *toolPath = [self.launchPath fileSystemRepresentation];
    
    // first, construct an array of c strings from NSArray w. arguments
    for (int i = 0; i < numberOfArguments; i++) {
        NSString *argString = arguments[i];
        const char *fsrep = [argString fileSystemRepresentation];
        NSUInteger stringLength = strlen(fsrep);
        
        args[i] = malloc((stringLength + 1) * sizeof(char));
        snprintf(args[i], stringLength + 1, "%s", fsrep);
    }
    args[numberOfArguments] = NULL;
    
    // change to the current dir specified
    char *prevCwd = (char *)getcwd(nil, 0);
    chdir([self.currentDirectoryPath fileSystemRepresentation]);
    
    //use Authorization Reference to execute script with privileges
    OSStatus err = _AuthExecuteWithPrivsFn(authorization, toolPath, kAuthorizationFlagDefaults, args, &outputFile);
#endif
    
    // OK, now we're done executing, let's change back to old dir
    chdir(prevCwd);
    
    // free the malloc'd argument strings
#ifdef PLATYPUS_HEAD
    for (i = 0; i < argumentsCount; i++)
        free(args[i]);
    
    // free the auth ref
    AuthorizationFree(authorizationRef, kAuthorizationFlagDefaults);
    
    // we return err if execution failed
    if (err != errAuthorizationSuccess) 
        return err;
    else
        isRunning = YES;
    
    // get file handle for the command output
    outputFileHandle = [[NSFileHandle alloc] initWithFileDescriptor: fileno(outputFile) closeOnDealloc: YES];
    pid = fcntl(fileno(outputFile), F_GETOWN, 0);
    
    // start monitoring task
    checkStatusTimer = [NSTimer scheduledTimerWithTimeInterval: 0.10 target: self selector:@selector(_checkTaskStatus) userInfo: nil repeats: YES];
        
#else
    for (int i = 0; i < numberOfArguments; i++) {
        free(args[i]);
    }
    
    // we return err if execution failed
    if (err != errAuthorizationSuccess) {
        return err;
    } else {
        _isRunning = YES;
    }
    
    // get file handle for the command output
    _outputFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fileno(outputFile) closeOnDealloc:YES];
    _processIdentifier = fcntl(fileno(outputFile), F_GETOWN, 0);
    
    // start monitoring task
    _checkStatusTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(checkTaskStatus) userInfo:nil repeats:YES];
    
#endif
    return err;
}

- (void)terminate
{
#ifdef PLATYPUS_HEAD
    // This doesn't work without a PID, and we can't get one.  Stupid Security API
#if 0
    int ret = kill(pid, SIGKILL);
     
     if (ret != 0)
     	NSLog(@"Error %d", errno);
#else
    // This doesn't work without a PID, and we can't get one. Stupid Security API.
#if 0
    int ret = kill(pid, SIGKILL);
     
    if (ret != 0) {
        NSLog(@"Error %d", errno);
    }
#endif
#endif
}

// hang until task is done
#ifdef PLATYPUS_HEAD
- (void)waitUntilExit
{
    waitpid([self processIdentifier], &terminationStatus, 0);
    isRunning = NO;
}

#pragma mark -

// check if privileged task is still running
- (void)_checkTaskStatus
{    
    // see if task has terminated
    int mypid = waitpid([self processIdentifier], &terminationStatus, WNOHANG);
    if (mypid != 0)
    {
        isRunning = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName: STPrivilegedTaskDidTerminateNotification object:self];
        [checkStatusTimer invalidate];
    }
}

#pragma mark -

- (NSString *)description
{
    NSArray *args = [self arguments];
    NSString *cmd = [self launchPath];
    int i;
    for (i = 0; i < [args count]; i++)
        cmd = [cmd stringByAppendingFormat: @" %@", [args objectAtIndex: i]];
    
    return [[super description] stringByAppendingFormat: @" %@", cmd];
}
#else
- (void)waitUntilExit
{
    if (!_isRunning) {
        NSLog(@"Task %@ is not running", [super description]);
        return;
    }
    
    [_checkStatusTimer invalidate];
    
    int status;
    pid_t pid = 0;
    while ((pid = waitpid(_processIdentifier, &status, WNOHANG)) == 0) {
        // do nothing
    }
    _terminationStatus = WEXITSTATUS(status);
    _isRunning = NO;
}

// check if task has terminated
- (void)checkTaskStatus
{
    int status;
    pid_t pid = waitpid(_processIdentifier, &status, WNOHANG);
    if (pid != 0) {
        _isRunning = NO;
        _terminationStatus = WEXITSTATUS(status);
        [_checkStatusTimer invalidate];
        [[NSNotificationCenter defaultCenter] postNotificationName:STPrivilegedTaskDidTerminateNotification object:self];
        if (_terminationHandler) {
            _terminationHandler(self);
        }
    }
}
#endif

#pragma mark -

+ (BOOL)authorizationFunctionAvailable
{
    if (!_AuthExecuteWithPrivsFn) {
        // This version of OS X has finally removed this function. Return with an error.
        return NO;
    }
    return YES;
}

#pragma mark -

#ifdef PLATYPUS_HEAD
static OSStatus AuthorizationExecuteWithPrivilegesStdErrAndPid (AuthorizationRef authorization,
                                                                const char *pathToTool,
                                                                AuthorizationFlags options,
                                                                char * const *arguments,
                                                                FILE **communicationsPipe,
                                                                FILE **errPipe,
                                                                pid_t* processid)
{
    // get the Apple-approved secure temp directory
    NSString *tempFileTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent: TMP_STDERR_TEMPLATE];
    
    // copy it into a C string
    const char *tempFileTemplateCString = [tempFileTemplate fileSystemRepresentation];
    char *stderrpath = (char *)malloc(strlen(tempFileTemplateCString) + 1);
    strcpy(stderrpath, tempFileTemplateCString);
    
    printf("%s\n", stderrpath);
    
    // this is the command, it echoes pid and directs stderr output to pipe before running the tool w. args
    const char *commandtemplate = "echo $$; \"$@\" 2>%s";
    
    if (communicationsPipe == errPipe)
        commandtemplate = "echo $$; \"$@\" 2>1";
    else if (errPipe == 0)
        commandtemplate = "echo $$; \"$@\"";
    
    char        command[1024];
    char        **args;
    OSStatus    result;
    int            argcount = 0;
    int            i;
    int            stderrfd = 0;
    FILE        *commPipe = 0;
    
    // First, create temporary file for stderr
    if (errPipe) 
    {
        // create temp file
        stderrfd = mkstemp(stderrpath);
        
        // close and remove it
        close(stderrfd); 
        unlink(stderrpath);
                
        // create a pipe on the path of the temp file
        if (mkfifo(stderrpath,S_IRWXU | S_IRWXG) != 0)
        {
            fprintf(stderr,"Error mkfifo:%d\n", errno);
            return errAuthorizationInternal;
        }
        
        if (stderrfd < 0)
            return errAuthorizationInternal;
    }
    
    // Create command to be executed
    for (argcount = 0; arguments[argcount] != 0; ++argcount) {}
    args = (char**)malloc (sizeof(char*)*(argcount + 5));
    args[0] = "-c";
    snprintf (command, sizeof (command), commandtemplate, stderrpath);
    args[1] = command;
    args[2] = "";
    args[3] = (char*)pathToTool;
    for (i = 0; i < argcount; ++i) {
        args[i+4] = arguments[i];
    }
    args[argcount+4] = 0;
    
    // for debugging: log the executed command
    printf ("Exec:\n%s", "/bin/sh"); for (i = 0; args[i] != 0; ++i) { printf (" \"%s\"", args[i]); } printf ("\n");
    
    // Execute command
    result = AuthorizationExecuteWithPrivileges(authorization, "/bin/sh",  options, args, &commPipe );
    if (result != noErr) 
    {
        unlink (stderrpath);
        return result;
    }
    
    // Read the first line of stdout => it's the pid
    {
        int stdoutfd = fileno (commPipe);
        char pidnum[1024];
        pid_t pid = 0;
        int i = 0;
        char ch = 0;
        
        while ((read(stdoutfd, &ch, sizeof(ch)) == 1) && (ch != '\n') && (i < sizeof(pidnum))) 
        {
            pidnum[i++] = ch;
        }
        pidnum[i] = 0;
        
        if (ch != '\n') 
        {
            // we shouldn't get there
            unlink (stderrpath);
            return errAuthorizationInternal;
        }
        sscanf(pidnum, "%d", &pid);
        if (processid) 
        {
            *processid = pid;
        }
        NSLog(@"Have PID %d", pid);
    }
    
    // 
    if (errPipe) {
        stderrfd = open(stderrpath, O_RDONLY, 0);
#if 0
        *errPipe = fdopen(stderrfd, "r");
#endif
         //Now it's safe to unlink the stderr file, as the opened handle will be still valid
        unlink (stderrpath);
    } else {
        unlink(stderrpath);
    }
    
    if (communicationsPipe) 
        *communicationsPipe = commPipe;
    else
        fclose (commPipe);
    
    NSLog(@"AuthExecNew function over");
    
    return noErr;
}
#else 
// Nice description for debugging
- (NSString *)description
{
    NSString *commandDescription = [NSString stringWithString:self.launchPath];
    
    for (NSString *arg in self.arguments) {
        commandDescription = [commandDescription stringByAppendingFormat:@" '%@'", arg];
    }
    [commandDescription stringByAppendingFormat:@" (CWD:%@)", self.currentDirectoryPath];
    
    return [[super description] stringByAppendingFormat:@" %@", commandDescription];
}

@end /* end to implementation of STPrivilegedTask; only in ifdef PLATYPUS_HEAD */
#endif
