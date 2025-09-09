#import <UIKit/UIKit.h>
#import "ClassDumpRuntime/ClassDump/ClassDump.h"
#import "IOSLogger.h"
#import "DYDumpHeaderDumper.h"
#import "DYDumpHeaderDumperUI.h"

UIViewController *getTopMostViewController() {
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    return topViewController;
}

%hook AppDelegate  
- (_Bool)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)arg2 {
    %orig;

    UIViewController *topViewController = getTopMostViewController();
	[DYDumpHeaderDumperUI presentFromViewController:topViewController];
    
    return true;
}
%end

%ctor {
    [[iOSLogger sharedInstance] startLoggingWithHost:@"192.168.100.6" port:5021];
    LogMessage(@"dydump loaded");
}