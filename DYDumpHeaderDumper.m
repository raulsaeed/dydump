// DYDumpHeaderDumper.m

#import "DYDumpHeaderDumper.h"
#import <libkern/OSAtomic.h>
#import "IOSLogger.h"

// --- Presumed imports for the Class-Dump library ---
// You will need to import the headers for the class-dumping
// utilities you are using. For example:
#import "ClassDumpRuntime/ClassDump/Services/CDUtilities.h"
#import "ClassDumpRuntime/ClassDump/Models/Reflections/CDClassModel.h"
#import "ClassDumpRuntime/ClassDump/Models/CDGenerationOptions.h"
#import "ClassDumpRuntime/ClassDump/Models/CDSemanticString.h"


// --- Private Constants and Helper Functions ---

// The UserDefaults key is now a private constant within this file.
static NSString * const kDYDumpedHeadersKey = @"DYDumpDidDumpHeaders";

// Helper C-style functions are kept static to this implementation file.
static NSString *DYDump_GetDocumentsDirectory() {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths firstObject];
}

static BOOL DYDump_CreateDirectoryAtPath(NSString *path) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        NSError *error = nil;
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            LogMessage(@"[DYDump] Error creating directory at path %@: %@", path, error.localizedDescription);
            return NO;
        }
    }
    return YES;
}


// --- Class Implementation ---

@implementation DYDumpHeaderDumper

+ (void)dumpAllClassHeaders {
    // Check if headers have already been dumped
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kDYDumpedHeadersKey]) {
        LogMessage(@"[DYDump] Class headers already dumped. Skipping.");
        return;
    }

    LogMessage(@"[DYDump] Starting ALL class header dump...");
    
    // Create the "headers" directory
    NSString *documentsPath = DYDump_GetDocumentsDirectory();
    if (!documentsPath) {
        LogMessage(@"[DYDump] Could not find documents directory. Aborting header dump.");
        return;
    }
    NSString *headersFolderPath = [documentsPath stringByAppendingPathComponent:[self generateTimestampedDirectoryName]];
    if (!DYDump_CreateDirectoryAtPath(headersFolderPath)) {
        LogMessage(@"[DYDump] Failed to create 'headers' directory. Aborting header dump.");
        return;
    }

    // Get all class names
    NSArray<NSString *> *allClassNames = [CDUtilities classNames];
    if (allClassNames.count == 0) {
        LogMessage(@"[DYDump] No classes found to dump.");
        [defaults setBool:YES forKey:kDYDumpedHeadersKey];
        return;
    }
    
    LogMessage(@"[DYDump] Found %lu Objective-C classes. Preparing to dump concurrently.", (unsigned long)allClassNames.count);

    // Prepare generation options (can be shared across threads)
    CDGenerationOptions *options = [CDGenerationOptions new];
    options.addSymbolImageComments = NO;
    options.stripSynthesized = NO;
    options.stripOverrides = YES;
    options.stripProtocolConformance = YES;
    options.stripDuplicates = YES;

    // Create a concurrent queue and a dispatch group
    dispatch_queue_t dumpQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_group_t dumpGroup = dispatch_group_create();

    // Use thread-safe counters for statistics
    __block int32_t dumpedCount = 0;
    __block int32_t skippedCount = 0;
    __block int32_t errorCount = 0;

    // Start timing
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    LogMessage(@"[DYDump] Concurrent dump task started...");

    // Iterate and dispatch a task for each class
    for (NSString *className in allClassNames) {
        dispatch_group_async(dumpGroup, dumpQueue, ^{
            @autoreleasepool {
                if (![CDUtilities isClassSafeToInspect:className]) { OSAtomicIncrement32(&skippedCount); return; }
                Class targetClass = NSClassFromString(className);
                if (!targetClass) { OSAtomicIncrement32(&skippedCount); return; }
                CDClassModel *classModel = [CDClassModel modelWithClass:targetClass];
                if (!classModel) { OSAtomicIncrement32(&skippedCount); return; }

                CDSemanticString *semanticHeader = [classModel semanticLinesWithOptions:options];
                NSString *classHeader = [semanticHeader string];
                NSString *fileName = [NSString stringWithFormat:@"%@.h", className];
                NSString *filePath = [headersFolderPath stringByAppendingPathComponent:fileName];

                NSError *writeError = nil;
                [classHeader writeToFile:filePath atomically:NO encoding:NSUTF8StringEncoding error:&writeError];

                if (writeError) {
                    OSAtomicIncrement32(&errorCount);
                } else {
                    int32_t currentCount = OSAtomicIncrement32(&dumpedCount);
                    
                    if ( (currentCount <= 10) ||
                         (currentCount <= 500 && currentCount % 50 == 0) ||
                         (currentCount <= 2000 && currentCount % 250 == 0) ||
                         (currentCount > 2000 && currentCount % 1000 == 0) )
                    {
                        LogMessage(@"[DYDump] Dumped %d/%lu: %@", currentCount, (unsigned long)allClassNames.count, className);
                    }
                }
            }
        });
    }

    // This block will be executed only after ALL tasks in the group are finished
    dispatch_group_notify(dumpGroup, dispatch_get_main_queue(), ^{
        CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
        double timeElapsed = endTime - startTime;

        LogMessage(@"[DYDump] ALL class header dump complete in %.2f seconds.", timeElapsed);
        LogMessage(@"[DYDump] Results: Dumped %d files, Skipped %d classes, %d file errors.", dumpedCount, skippedCount, errorCount);
        
        [defaults setBool:YES forKey:kDYDumpedHeadersKey];
        LogMessage(@"[DYDump] NSUserDefaults flag set to YES.");
    });
}

+ (void)dumpClassHeaders:(NSArray<NSString *> *)classNames withOptions:(NSDictionary *)options {
    if (!classNames || classNames.count == 0) {
        LogMessage(@"[DYDump] No classes provided to dump.");
        return;
    }
    
    LogMessage(@"[DYDump] Starting targeted class header dump for %lu classes...", (unsigned long)classNames.count);
    
    // Create the "headers" directory
    NSString *documentsPath = DYDump_GetDocumentsDirectory();
    if (!documentsPath) {
        LogMessage(@"[DYDump] Could not find documents directory. Aborting header dump.");
        return;
    }
    NSString *headersFolderPath = [documentsPath stringByAppendingPathComponent:[self generateTimestampedDirectoryName]];
    if (!DYDump_CreateDirectoryAtPath(headersFolderPath)) {
        LogMessage(@"[DYDump] Failed to create 'headers' directory. Aborting header dump.");
        return;
    }
    
    // Prepare generation options from the UI
    CDGenerationOptions *generationOptions = [CDGenerationOptions new];
    generationOptions.addSymbolImageComments = [options[@"addSymbolImageComments"] boolValue];
    generationOptions.stripSynthesized = [options[@"stripSynthesized"] boolValue];
    generationOptions.stripOverrides = [options[@"stripOverrides"] boolValue];
    generationOptions.stripProtocolConformance = [options[@"stripProtocolConformance"] boolValue];
    generationOptions.stripDuplicates = [options[@"stripDuplicates"] boolValue];
    
    // Create a concurrent queue and a dispatch group
    dispatch_queue_t dumpQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_group_t dumpGroup = dispatch_group_create();
    
    // Use thread-safe counters for statistics
    __block int32_t dumpedCount = 0;
    __block int32_t skippedCount = 0;
    __block int32_t errorCount = 0;
    
    // Start timing
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    LogMessage(@"[DYDump] Targeted dump task started...");
    
    // Iterate and dispatch a task for each class
    for (NSString *className in classNames) {
        dispatch_group_async(dumpGroup, dumpQueue, ^{
            @autoreleasepool {
                if (![CDUtilities isClassSafeToInspect:className]) { OSAtomicIncrement32(&skippedCount); return; }
                Class targetClass = NSClassFromString(className);
                if (!targetClass) { OSAtomicIncrement32(&skippedCount); return; }
                CDClassModel *classModel = [CDClassModel modelWithClass:targetClass];
                if (!classModel) { OSAtomicIncrement32(&skippedCount); return; }

                CDSemanticString *semanticHeader = [classModel semanticLinesWithOptions:generationOptions];
                NSString *classHeader = [semanticHeader string];
                NSString *fileName = [NSString stringWithFormat:@"%@.h", className];
                NSString *filePath = [headersFolderPath stringByAppendingPathComponent:fileName];

                NSError *writeError = nil;
                [classHeader writeToFile:filePath atomically:NO encoding:NSUTF8StringEncoding error:&writeError];

                if (writeError) {
                    OSAtomicIncrement32(&errorCount);
                } else {
                    int32_t currentCount = OSAtomicIncrement32(&dumpedCount);
                    
                    if ( (currentCount <= 10) ||
                         (currentCount <= 500 && currentCount % 50 == 0) ||
                         (currentCount <= 2000 && currentCount % 250 == 0) ||
                         (currentCount > 2000 && currentCount % 1000 == 0) )
                    {
                        LogMessage(@"[DYDump] Dumped %d/%lu: %@", currentCount, (unsigned long)classNames.count, className);
                    }
                }
            }
        });
    }
    
    // This block will be executed only after ALL tasks in the group are finished
    dispatch_group_notify(dumpGroup, dispatch_get_main_queue(), ^{
        CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
        double timeElapsed = endTime - startTime;

        LogMessage(@"[DYDump] Targeted class header dump complete in %.2f seconds.", timeElapsed);
        LogMessage(@"[DYDump] Results: Dumped %d files, Skipped %d classes, %d file errors.", dumpedCount, skippedCount, errorCount);
    });
}

+ (void)dumpClassHeaders:(NSArray<NSString *> *)classNames 
             withOptions:(NSDictionary *)options 
        progressCallback:(void(^)(NSInteger completed, NSInteger total, NSString *currentClass))progressCallback
          cancelCallback:(BOOL(^)(void))cancelCallback
      completionCallback:(void(^)(BOOL cancelled, NSInteger dumped, NSInteger skipped, NSInteger errors))completionCallback {
    
    if (!classNames || classNames.count == 0) {
        LogMessage(@"[DYDump] No classes provided to dump.");
        if (completionCallback) completionCallback(NO, 0, 0, 0);
        return;
    }
    
    LogMessage(@"[DYDump] Starting targeted class header dump for %lu classes...", (unsigned long)classNames.count);
    
    // Create the "headers" directory
    NSString *documentsPath = DYDump_GetDocumentsDirectory();
    if (!documentsPath) {
        LogMessage(@"[DYDump] Could not find documents directory. Aborting header dump.");
        if (completionCallback) completionCallback(NO, 0, 0, 1);
        return;
    }
    NSString *headersFolderPath = [documentsPath stringByAppendingPathComponent:[self generateTimestampedDirectoryName]];
    if (!DYDump_CreateDirectoryAtPath(headersFolderPath)) {
        LogMessage(@"[DYDump] Failed to create 'headers' directory. Aborting header dump.");
        if (completionCallback) completionCallback(NO, 0, 0, 1);
        return;
    }
    
    // Prepare generation options from the UI
    CDGenerationOptions *generationOptions = [CDGenerationOptions new];
    generationOptions.addSymbolImageComments = [options[@"addSymbolImageComments"] boolValue];
    generationOptions.stripSynthesized = [options[@"stripSynthesized"] boolValue];
    generationOptions.stripOverrides = [options[@"stripOverrides"] boolValue];
    generationOptions.stripProtocolConformance = [options[@"stripProtocolConformance"] boolValue];
    generationOptions.stripDuplicates = [options[@"stripDuplicates"] boolValue];
    
    // Create a concurrent queue and a dispatch group
    dispatch_queue_t dumpQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_group_t dumpGroup = dispatch_group_create();
    
    // Use thread-safe counters for statistics
    __block int32_t dumpedCount = 0;
    __block int32_t skippedCount = 0;
    __block int32_t errorCount = 0;
    __block int32_t processedCount = 0;
    __block BOOL wasCancelled = NO;
    
    // Start timing
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    LogMessage(@"[DYDump] Targeted dump task started...");
    
    // Iterate and dispatch a task for each class
    for (NSString *className in classNames) {
        dispatch_group_async(dumpGroup, dumpQueue, ^{
            @autoreleasepool {
                // Check for cancellation
                if (cancelCallback && cancelCallback()) {
                    wasCancelled = YES;
                    return;
                }
                
                if (![CDUtilities isClassSafeToInspect:className]) { 
                    OSAtomicIncrement32(&skippedCount); 
                    int32_t currentProcessed = OSAtomicIncrement32(&processedCount);
                    if (progressCallback) {
                        progressCallback(currentProcessed, classNames.count, className);
                    }
                    return; 
                }
                
                Class targetClass = NSClassFromString(className);
                if (!targetClass) { 
                    OSAtomicIncrement32(&skippedCount); 
                    int32_t currentProcessed = OSAtomicIncrement32(&processedCount);
                    if (progressCallback) {
                        progressCallback(currentProcessed, classNames.count, className);
                    }
                    return; 
                }
                
                CDClassModel *classModel = [CDClassModel modelWithClass:targetClass];
                if (!classModel) { 
                    OSAtomicIncrement32(&skippedCount); 
                    int32_t currentProcessed = OSAtomicIncrement32(&processedCount);
                    if (progressCallback) {
                        progressCallback(currentProcessed, classNames.count, className);
                    }
                    return; 
                }

                // Check for cancellation before expensive operations
                if (cancelCallback && cancelCallback()) {
                    wasCancelled = YES;
                    return;
                }

                CDSemanticString *semanticHeader = [classModel semanticLinesWithOptions:generationOptions];
                
                // Check for cancellation after semantic generation (most expensive part)
                if (cancelCallback && cancelCallback()) {
                    wasCancelled = YES;
                    return;
                }
                
                NSString *classHeader = [semanticHeader string];
                
                // Final cancellation check before writing file
                if (cancelCallback && cancelCallback()) {
                    wasCancelled = YES;
                    return;
                }
                
                NSString *fileName = [NSString stringWithFormat:@"%@.h", className];
                NSString *filePath = [headersFolderPath stringByAppendingPathComponent:fileName];

                NSError *writeError = nil;
                [classHeader writeToFile:filePath atomically:NO encoding:NSUTF8StringEncoding error:&writeError];

                if (writeError) {
                    OSAtomicIncrement32(&errorCount);
                } else {
                    OSAtomicIncrement32(&dumpedCount);
                }
                
                int32_t currentProcessed = OSAtomicIncrement32(&processedCount);
                
                // Call progress callback
                if (progressCallback) {
                    progressCallback(currentProcessed, classNames.count, className);
                }
                
                // Log progress occasionally
                if ( (currentProcessed <= 10) ||
                     (currentProcessed <= 500 && currentProcessed % 50 == 0) ||
                     (currentProcessed <= 2000 && currentProcessed % 250 == 0) ||
                     (currentProcessed > 2000 && currentProcessed % 1000 == 0) )
                {
                    LogMessage(@"[DYDump] Processed %d/%lu: %@", currentProcessed, (unsigned long)classNames.count, className);
                }
            }
        });
    }
    
    // This block will be executed only after ALL tasks in the group are finished
    dispatch_group_notify(dumpGroup, dispatch_get_main_queue(), ^{
        CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
        double timeElapsed = endTime - startTime;

        LogMessage(@"[DYDump] Targeted class header dump complete in %.2f seconds.", timeElapsed);
        LogMessage(@"[DYDump] Results: Dumped %d files, Skipped %d classes, %d file errors. Cancelled: %@", 
                  dumpedCount, skippedCount, errorCount, wasCancelled ? @"YES" : @"NO");
        
        if (completionCallback) {
            completionCallback(wasCancelled, dumpedCount, skippedCount, errorCount);
        }
    });
}

+ (NSString *)generateTimestampedDirectoryName {
    // Get the app name
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    if (!appName) {
        appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    }
    if (!appName) {
        appName = @"UnknownApp";
    }
    
    // Clean app name of invalid characters for file system
    NSCharacterSet *invalidChars = [NSCharacterSet characterSetWithCharactersInString:@"/:*?\"<>|"];
    appName = [[appName componentsSeparatedByCharactersInSet:invalidChars] componentsJoinedByString:@"_"];
    
    // Get current timestamp
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    // Create directory name: AppName_headers_YYYY-MM-dd_HH-mm-ss
    return [NSString stringWithFormat:@"%@_headers_%@", appName, timestamp];
}

@end