// DYDumpHeaderDumper.h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A utility class for dumping all Objective-C class headers from the application.
 *
 * This class performs the dump operation concurrently to maximize speed and
 * provides dynamic logging to show progress without a significant performance impact.
 */
@interface DYDumpHeaderDumper : NSObject

/**
 * Initiates the class header dumping process.
 *
 * The process runs on a background thread, checks if a dump has already been
 * performed to prevent re-running, and saves all generated .h files to a "headers"
 * subdirectory within the app's Documents directory.
 */
+ (void)dumpAllClassHeaders;

/**
 * Dumps headers for specific classes with custom options.
 *
 * @param classNames Array of class names to dump
 * @param options Dictionary containing generation options
 */
+ (void)dumpClassHeaders:(NSArray<NSString *> *)classNames withOptions:(NSDictionary *)options;

/**
 * Dumps headers for specific classes with custom options and progress tracking.
 *
 * @param classNames Array of class names to dump
 * @param options Dictionary containing generation options
 * @param progressCallback Block called for progress updates (completed, total, currentClass)
 * @param cancelCallback Block that returns YES if the operation should be cancelled
 * @param completionCallback Block called when operation completes (cancelled, dumped, skipped, errors)
 */
+ (void)dumpClassHeaders:(NSArray<NSString *> *)classNames 
             withOptions:(NSDictionary *)options 
        progressCallback:(void(^)(NSInteger completed, NSInteger total, NSString *currentClass))progressCallback
          cancelCallback:(BOOL(^)(void))cancelCallback
      completionCallback:(void(^)(BOOL cancelled, NSInteger dumped, NSInteger skipped, NSInteger errors))completionCallback;

/**
 * Generates a timestamped directory name with app name
 * 
 * @return Directory name in format "AppName_headers_YYYY-MM-dd_HH-mm-ss"
 */
+ (NSString *)generateTimestampedDirectoryName;

@end

NS_ASSUME_NONNULL_END