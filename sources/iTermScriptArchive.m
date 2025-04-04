//
//  iTermScriptArchive.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 6/24/18.
//

#import "iTermScriptArchive.h"

#import "DebugLogging.h"
#import "iTermPythonRuntimeDownloader.h"
#import "iTermSetupCfgParser.h"
#import "iTermWarning.h"
#import "NSArray+iTerm.h"
#import "NSFileManager+iTerm.h"
#import "NSJSONSerialization+iTerm.h"
#import "NSObject+iTerm.h"
#import "NSStringITerm.h"
#import "RegexKitLite.h"

NSString *const iTermScriptSetupCfgName = @"setup.cfg";
NSString *const iTermScriptDeprecatedSetupPyName = @"setup.py";
NSString *const iTermScriptMetadataName = @"metadata.json";

@interface iTermScriptArchive()
@property (nonatomic, copy, readwrite) NSString *container;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, strong, readwrite) NSDictionary *metadata;
@property (nonatomic, readwrite) BOOL fullEnvironment;
@end

@implementation iTermScriptArchive

+ (instancetype)archiveForScriptIn:(NSString *)container
                             named:(NSString *)name
                   fullEnvironment:(BOOL)fullEnvironment {
    iTermScriptArchive *archive = [[self alloc] init];
    archive.container = container.copy;
    archive.name = name.copy;
    archive.fullEnvironment = fullEnvironment;
    archive.metadata = [self metadataInContainer:container name:name];
    return archive;
}

+ (NSDictionary *)metadataInContainer:(NSString *)container name:(NSString *)name {
    NSString *path = [[container stringByAppendingPathComponent:name] stringByAppendingPathComponent:@"metadata.json"];
    NSString *stringValue = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!stringValue) {
        return nil;
    }
    return [NSDictionary castFrom:[NSJSONSerialization it_objectForJsonString:stringValue]];
}

+ (NSArray<NSString *> *)absolutePathsOfNonDotFilesIn:(NSString *)container {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSString *> *topLevelItems = [fileManager it_itemsInDirectory:container];
    topLevelItems = [topLevelItems filteredArrayUsingBlock:^BOOL(NSString *anObject) {
        return ![anObject hasPrefix:@"."];
    }];
    topLevelItems = [topLevelItems mapWithBlock:^id(NSString *anObject) {
        return [container stringByAppendingPathComponent:anObject];
    }];
    return topLevelItems;
}

+ (instancetype)archiveFromContainer:(NSString *)container
                          deprecated:(out BOOL *)deprecatedPtr {
    if (deprecatedPtr) {
        *deprecatedPtr = NO;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSString *> *topLevelItems = [self absolutePathsOfNonDotFilesIn:container];
    if (topLevelItems.count != 1) {
        return nil;
    }

    NSString *topLevelItem = topLevelItems.firstObject;
    const BOOL topLevelItemIsDirectory = [fileManager itemIsDirectory:topLevelItem];
    if ([[topLevelItem pathExtension] isEqualToString:@"py"] &&
        !topLevelItemIsDirectory &&
        [topLevelItem isEqualToString:[container stringByAppendingPathComponent:topLevelItem.lastPathComponent]]) {
        // Basic script
        return [iTermScriptArchive archiveForScriptIn:container named:topLevelItems[0].lastPathComponent fullEnvironment:NO];
    }
    if (!topLevelItemIsDirectory) {
        // File not ending in .py
        return nil;
    }

    NSArray<NSString *> *innerItems = [self absolutePathsOfNonDotFilesIn:topLevelItem];
    if (innerItems.count < 2) {
        return nil;
    }
    // Maps a boolean number to an item name. True key = setup.cfg, false key = not setup.py
    NSString *setupCfg = [topLevelItem stringByAppendingPathComponent:iTermScriptSetupCfgName];
    NSString *deprecatedSetupPy = [topLevelItem stringByAppendingPathComponent:iTermScriptDeprecatedSetupPyName];
    NSString *metadata = [topLevelItem stringByAppendingPathComponent:iTermScriptMetadataName];
    NSArray<NSString *> *requiredFiles = @[ setupCfg ];
    NSArray<NSString *> *optionalFiles = @[ metadata ];
    NSString *folder = nil;

    for (NSString *item in innerItems) {
        if ([requiredFiles containsObject:item]) {
            requiredFiles = [requiredFiles arrayByRemovingObject:item];
            continue;
        }
        if ([optionalFiles containsObject:item]) {
            continue;
        }
        if (folder == nil && [fileManager itemIsDirectory:item]) {
            folder = item;
            continue;
        }
        if ([item isEqualToString:deprecatedSetupPy]) {
            if (deprecatedPtr) {
                *deprecatedPtr = YES;
            }
        }
        return nil;
    }
    if (!folder || requiredFiles.count) {
        return nil;
    }
    NSString *name = [folder lastPathComponent];
    BOOL isDirectory;
    // mainPy="dir/name/name.py"
    NSString *mainPy = [[topLevelItem stringByAppendingPathComponent:name] stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"py"]];
    if (![fileManager fileExistsAtPath:mainPy isDirectory:&isDirectory] ||
        isDirectory) {
        return nil;
    }

    return [iTermScriptArchive archiveForScriptIn:container named:name fullEnvironment:YES];
}

- (BOOL)wantsAutoLaunch {
    return [[NSNumber castFrom:self.metadata[@"AutoLaunch"]] boolValue];
}

- (BOOL)userAcceptsTrustedScriptAutoLaunchInstall {
    NSString *body = [NSString stringWithFormat:@"“%@” would like to launch automatically when iTerm2 starts. Would you like to allow that?", self.name];
    const iTermWarningSelection selection = [iTermWarning showWarningWithTitle:body
                                                                       actions:@[ @"Launch Automatically", @"Lauch Manually" ]
                                                                     accessory:nil
                                                                    identifier:nil
                                                                   silenceable:kiTermWarningTypePersistent
                                                                       heading:@"Allow Auto-Launch?"
                                                                        window:nil];
    return (selection == kiTermWarningSelection0);
}

- (BOOL)userAcceptsExplicitAutoLaunchInstall {
    NSString *body = [NSString stringWithFormat:@"“%@” can launch automatically when iTerm2 starts. Would you like to allow that?", self.name];
    const iTermWarningSelection selection = [iTermWarning showWarningWithTitle:body
                                                                       actions:@[ @"Launch Automatically", @"Lauch Manually" ]
                                                                     accessory:nil
                                                                    identifier:nil
                                                                   silenceable:kiTermWarningTypePersistent
                                                                       heading:@"Allow Auto-Launch?"
                                                                        window:nil];
    return (selection == kiTermWarningSelection0);
}

- (void)installTrusted:(BOOL)trusted
       offerAutoLaunch:(BOOL)offerAutoLaunch
               avoidUI:(BOOL)avoidUI
        withCompletion:(void (^)(NSError *, NSURL *location))completion {
    DLog(@"trusted=%@ offerAutoLaunch=%@", @(trusted), @(offerAutoLaunch));
    if (self.fullEnvironment) {
        [self installFullEnvironmentTrusted:trusted
                            offerAutoLaunch:offerAutoLaunch
                                    avoidUI:avoidUI
                                 completion:completion];
    } else {
        [self installBasicTrusted:trusted
                  offerAutoLaunch:offerAutoLaunch
                          avoidUI:avoidUI
                       completion:completion];
    }
}

- (void)installBasicTrusted:(BOOL)trusted
            offerAutoLaunch:(BOOL)offerAutoLaunch
                    avoidUI:(BOOL)avoidUI
                 completion:(void (^)(NSError *, NSURL *location))completion {
    NSString *from = [self.container stringByAppendingPathComponent:self.name];
    NSString *to;
    if ([self shouldAutoLaunchWhenTrusted:trusted offerAutoLaunch:offerAutoLaunch avoidUI:avoidUI]) {
        to = [[[NSFileManager defaultManager] autolaunchScriptPathCreatingLink] stringByAppendingPathComponent:self.name];
    } else {
        to = [[[NSFileManager defaultManager] scriptsPathWithoutSpaces] stringByAppendingPathComponent:self.name];
    }
    NSError *error = nil;
    [[NSFileManager defaultManager] moveItemAtPath:from
                                            toPath:to
                                             error:&error];
    completion(error, [NSURL fileURLWithPath:to]);
}

- (BOOL)shouldOfferAutoLaunchWhenTrusted:(BOOL)trusted
                         offerAutoLaunch:(BOOL)offerAutoLaunch {
    if (offerAutoLaunch) {
        return YES;
    }
    if (trusted && [self wantsAutoLaunch]) {
        return YES;
    }
    return NO;
}

- (BOOL)shouldAutoLaunchWhenTrusted:(BOOL)trusted
                    offerAutoLaunch:(BOOL)offerAutoLaunch
                            avoidUI:(BOOL)avoidUI {
    if (![self shouldOfferAutoLaunchWhenTrusted:trusted offerAutoLaunch:offerAutoLaunch]) {
        return NO;
    }
    if (avoidUI) {
        return YES;
    }
    if (offerAutoLaunch) {
        return [self userAcceptsExplicitAutoLaunchInstall];
    } else {
        return [self userAcceptsTrustedScriptAutoLaunchInstall];
    }
}

- (void)installFullEnvironmentTrusted:(BOOL)trusted
                      offerAutoLaunch:(BOOL)offerAutoLaunch
                              avoidUI:(BOOL)avoidUI
                           completion:(void (^)(NSError *, NSURL *location))completion {
    DLog(@"trusted=%@ offerAutoLaunch=%@", @(trusted), @(offerAutoLaunch));
    NSString *from = [self.container stringByAppendingPathComponent:self.name];

    NSString *setupCfg = [from stringByAppendingPathComponent:iTermScriptSetupCfgName];
    iTermSetupCfgParser *setupParser = [[iTermSetupCfgParser alloc] initWithPath:setupCfg];
    if (!setupParser) {
        DLog(@"Can't find setup.cfg");
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: @"Cannot find setup.cfg" };
        NSError *error = [NSError errorWithDomain:@"com.iterm2.scriptarchive" code:1 userInfo:userInfo];
        completion(error, nil);
        return;
    }

    NSArray<NSString *> *dependencies = setupParser.dependencies;
    if (setupParser.dependenciesError) {
        DLog(@"deps error %@", setupParser.dependenciesError);
        completion(setupParser.dependenciesError, nil);
        return;
    }

    // You always get the iterm2 module so don't bother to pip install it.
    dependencies = [dependencies arrayByRemovingObject:@"iterm2"];

    // Decide where to put it and make the directory if needed.
    NSString *containingFolder;
    if ([self shouldAutoLaunchWhenTrusted:trusted offerAutoLaunch:offerAutoLaunch avoidUI:avoidUI]) {
        containingFolder = [[NSFileManager defaultManager] autolaunchScriptPathCreatingLink];
    } else {
        containingFolder = [[NSFileManager defaultManager] scriptsPathWithoutSpaces];
    }
    DLog(@"mkdir %@", containingFolder);
    [[NSFileManager defaultManager] createDirectoryAtPath:containingFolder
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    NSString *to = [containingFolder stringByAppendingPathComponent:self.name];

    // Create a symlink from the final location to the temporary location so shebangs will work.
    // First try to remove a dangling link.
    if ([[[[NSFileManager defaultManager] attributesOfItemAtPath:to error:nil] fileType] isEqualToString:NSFileTypeSymbolicLink]) {
        NSString *expanded = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:to error:nil];
        if (expanded && ![[NSFileManager defaultManager] fileExistsAtPath:expanded]) {
            DLog(@"rm %@", to);
            [[NSFileManager defaultManager] removeItemAtPath:to error:nil];
        }
    }

    NSError *error = nil;
    DLog(@"ln -s %@ %@", to, from);
    [[NSFileManager defaultManager] createSymbolicLinkAtPath:to
                                         withDestinationPath:from
                                                       error:&error];
    if (error) {
        DLog(@"%@", error);
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not write to %@", to] };
        NSError *error = [NSError errorWithDomain:@"com.iterm2.scriptarchive" code:1 userInfo:userInfo];
        completion(error, nil);
        return;
    }

    DLog(@"Will download optional components if needed");
    [[iTermPythonRuntimeDownloader sharedInstance] downloadOptionalComponentsIfNeededWithConfirmation:YES
                                                                                        pythonVersion:setupParser.pythonVersion
                                                                            minimumEnvironmentVersion:setupParser.minimumEnvironmentVersion
                                                                                   requiredToContinue:YES
                                                                                       withCompletion:
     ^(iTermPythonRuntimeDownloaderStatus status) {
        DLog(@"status=%@", @(status));
        switch (status) {
            case iTermPythonRuntimeDownloaderStatusRequestedVersionNotFound:
            case iTermPythonRuntimeDownloaderStatusCanceledByUser:
            case iTermPythonRuntimeDownloaderStatusUnknown:
            case iTermPythonRuntimeDownloaderStatusWorking:
            case iTermPythonRuntimeDownloaderStatusError: {
                [[NSFileManager defaultManager] removeItemAtPath:to error:nil];
                NSString *reason = [self errorReasonForRuntimeDownloaderStatus:status];
                NSString *description = [NSString stringWithFormat:@"Python Runtime not downloaded: %@", reason];
                NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: description };
                NSError *error = [NSError errorWithDomain:@"com.iterm2.scriptarchive" code:3 userInfo:userInfo];
                completion(error, nil);
                return;
            }

            case iTermPythonRuntimeDownloaderStatusNotNeeded:
            case iTermPythonRuntimeDownloaderStatusDownloaded:
                DLog(@"No need to download");
                break;
        }
        NSURL *toURL = [NSURL fileURLWithPath:to];
        DLog(@"Will install python environment to %@", from);
        [[iTermPythonRuntimeDownloader sharedInstance] installPythonEnvironmentTo:[NSURL fileURLWithPath:from]
                                                                 eventualLocation:toURL
                                                                    pythonVersion:setupParser.pythonVersion
                                                               environmentVersion:setupParser.minimumEnvironmentVersion
                                                                     dependencies:dependencies
                                                                   createSetupCfg:NO
                                                                       completion:^(NSError *errorStatus) {
            DLog(@"Install python environment done with status %@", errorStatus);
            [self didInstallPythonRuntimeWithError:errorStatus
                                              from:from
                                                to:to
                                        completion:
             ^(NSError *runtimeInstallError) {
                DLog(@"didInstallPythonRuntime done with error %@", runtimeInstallError);
                completion(runtimeInstallError,
                           runtimeInstallError == nil ? toURL : nil);
            }];
        }];
    }];
}

- (NSString *)errorReasonForRuntimeDownloaderStatus:(iTermPythonRuntimeDownloaderStatus)status {
    switch (status) {
        case iTermPythonRuntimeDownloaderStatusRequestedVersionNotFound:
            return @"Requested version not available";
        case iTermPythonRuntimeDownloaderStatusCanceledByUser:
            return @"Canceled by user";
        case iTermPythonRuntimeDownloaderStatusUnknown:
        case iTermPythonRuntimeDownloaderStatusWorking:
            return @"An unknown problem occurred";
        case iTermPythonRuntimeDownloaderStatusError:
            return @"Network error";
        case iTermPythonRuntimeDownloaderStatusNotNeeded:
        case iTermPythonRuntimeDownloaderStatusDownloaded:
            return nil;
    }
}

- (void)didInstallPythonRuntimeWithError:(NSError *)errorStatus
                                    from:(NSString *)from
                                      to:(NSString *)to
                              completion:(void (^)(NSError *))completion {
    DLog(@"status=%@ from=%@ to=%@", errorStatus, from, to);
    [[NSFileManager defaultManager] removeItemAtPath:to error:nil];
    switch ((iTermInstallPythonStatus)errorStatus.code) {
        case iTermInstallPythonStatusOK:
            DLog(@"ok");
            break;
        case iTermInstallPythonStatusGeneralFailure: {
            DLog(@"general failure");
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to install Python Runtime: %@", errorStatus.localizedDescription] };
            NSError *error = [NSError errorWithDomain:@"com.iterm2.scriptarchive" code:1 userInfo:userInfo];
            completion(error);
            return;
        }
        case iTermInstallPythonStatusDependencyFailed: {
            DLog(@"Dep failed");
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to install Python package: %@", errorStatus.localizedDescription] };
            NSError *error = [NSError errorWithDomain:@"com.iterm2.scriptarchive" code:2 userInfo:userInfo];
            completion(error);
            return;
        }
    }

    // Finally, move it to its destination.
    NSFileManager *fileManager = [NSFileManager defaultManager];
    // Remove the symlink that should have been dropped there.
    DLog(@"remove symlink %@", to);
    [fileManager removeItemAtPath:to error:nil];
    NSError *error = nil;
    DLog(@"move %@ to %@", from, to);
    [fileManager moveItemAtPath:from
                         toPath:to
                          error:&error];
    DLog(@"move error=%@", error);
    completion(error);
}

@end

