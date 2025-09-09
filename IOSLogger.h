#import <Foundation/Foundation.h>

#define LogMessage(...) \
do { \
    NSString *msg = [NSString stringWithFormat:__VA_ARGS__]; \
    NSLog(@"[dydump] %@", msg); \
    [[iOSLogger sharedInstance] sendLog:msg]; \
} while(0)


@interface iOSLogger : NSObject

+ (instancetype)sharedInstance;
- (void)sendLog:(NSString *)message;
- (void)startLoggingWithHost:(NSString *)host port:(int)port;
- (void)stopLogging;

@end