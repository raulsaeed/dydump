#import <UIKit/UIKit.h>
#import "ClassDumpRuntime/ClassDump/ClassDump.h"
#import "IOSLogger.h"
#import "DYDumpHeaderDumper.h"
#import "DYDumpHeaderDumperUI.h"

static BOOL hasShownUI = NO;

UIViewController *getTopMostViewController() {
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    return topViewController;
}

void showDYDumpUI() {
    if (hasShownUI) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *topViewController = getTopMostViewController();
        if (topViewController) {
            [DYDumpHeaderDumperUI presentFromViewController:topViewController];
            hasShownUI = YES;
        }
    });
}

%ctor {
    [[iOSLogger sharedInstance] startLoggingWithHost:@"192.168.100.6" port:5021];
    LogMessage(@"dydump loaded");
    
    // Fallback: try to show UI after a delay if no hooks triggered
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        showDYDumpUI();
    });
}