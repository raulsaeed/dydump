// DYDumpHeaderDumperUI.h

#import <UIKit/UIKit.h>

@interface DYDumpHeaderDumperUI : UIViewController <UIDocumentInteractionControllerDelegate>

+ (void)presentFromViewController:(UIViewController *)parentViewController;

@end