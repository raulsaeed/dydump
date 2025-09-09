// DYDumpHeaderDumperUI.m

#import "DYDumpHeaderDumperUI.h"
#import "DYDumpHeaderDumper.h"
#import "IOSLogger.h"
#import "ClassDumpRuntime/ClassDump/Services/CDUtilities.h"
#import <objc/runtime.h>

@interface DYDumpHeaderDumperUI ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

@property (nonatomic, strong) UITextField *includePatternField;
@property (nonatomic, strong) UITextField *excludePatternField;
@property (nonatomic, strong) UILabel *resultsLabel;

@property (nonatomic, strong) UISwitch *addSymbolImageCommentsSwitch;
@property (nonatomic, strong) UISwitch *stripSynthesizedSwitch;
@property (nonatomic, strong) UISwitch *stripOverridesSwitch;
@property (nonatomic, strong) UISwitch *stripProtocolConformanceSwitch;
@property (nonatomic, strong) UISwitch *stripDuplicatesSwitch;

@property (nonatomic, strong) UIButton *analyzeButton;
@property (nonatomic, strong) UIButton *dumpButton;

@property (nonatomic, strong) NSArray<NSString *> *filteredClassNames;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, assign) BOOL isDumping;
@property (nonatomic, assign) BOOL shouldCancelDump;
@property (nonatomic, assign) BOOL hasAnalyzed;
@property (nonatomic, strong) NSString *currentDumpDirectoryPath;

@end

@implementation DYDumpHeaderDumperUI

+ (void)presentFromViewController:(UIViewController *)parentViewController {
    DYDumpHeaderDumperUI *dumperUI = [[DYDumpHeaderDumperUI alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:dumperUI];
    [parentViewController presentViewController:navController animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Class Header Dumper";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(dismissViewController)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Credits" style:UIBarButtonItemStylePlain target:self action:@selector(showCredits)];
    
    self.hasAnalyzed = NO;
    
    [self setupUI];
    [self setupKeyboardDismissal];
    [self updateButtonStates];
}

- (void)dismissViewController {
    if (self.isDumping) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cancel Operation" 
                                                                       message:@"A dump operation is currently in progress. Are you sure you want to exit?" 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *continueAction = [UIAlertAction actionWithTitle:@"Continue" 
                                                                 style:UIAlertActionStyleCancel 
                                                               handler:nil];
        
        UIAlertAction *exitAction = [UIAlertAction actionWithTitle:@"Exit" 
                                                             style:UIAlertActionStyleDestructive 
                                                           handler:^(UIAlertAction * _Nonnull action) {
            self.shouldCancelDump = YES;
            [self dismissViewControllerAnimated:YES completion:nil];
        }];
        
        [alert addAction:continueAction];
        [alert addAction:exitAction];
        
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)showCredits {
    NSString *title = @"Credits";
    NSString *message = @"DYDump - ClassDumpRuntime UI Wrapper\n\n" \
                        @"This is a user-friendly interface for ClassDumpRuntime.\n\n" \
                        @"Developed by:\n" \
                        @"• Raul - UI Wrapper Developer\n" \
                        @"• leptos - ClassDumpRuntime Developer\n\n" \
                        @"ClassDumpRuntime is the core library that powers this tool.\n\n" \
                        @"Thank you for using DYDump!";
    
    UIAlertController *creditsAlert = [UIAlertController alertControllerWithTitle:title 
                                                                          message:message 
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *githubAction = [UIAlertAction actionWithTitle:@"View on GitHub" 
                                                           style:UIAlertActionStyleDefault 
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self showGitHubOptions];
    }];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" 
                                                       style:UIAlertActionStyleCancel 
                                                     handler:nil];
    
    [creditsAlert addAction:githubAction];
    [creditsAlert addAction:okAction];
    
    [self presentViewController:creditsAlert animated:YES completion:nil];
}

- (void)showGitHubOptions {
    UIAlertController *githubAlert = [UIAlertController alertControllerWithTitle:@"GitHub Links" 
                                                                         message:@"Choose which GitHub profile to visit:" 
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *raulAction = [UIAlertAction actionWithTitle:@"Raul's GitHub" 
                                                         style:UIAlertActionStyleDefault 
                                                       handler:^(UIAlertAction * _Nonnull action) {
        [self openURL:@"https://github.com/raulsaeed"];
    }];
    
    UIAlertAction *letposAction = [UIAlertAction actionWithTitle:@"letpos's GitHub" 
                                                           style:UIAlertActionStyleDefault 
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self openURL:@"https://github.com/leptos-null"];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" 
                                                           style:UIAlertActionStyleCancel 
                                                         handler:nil];
    
    [githubAlert addAction:raulAction];
    [githubAlert addAction:letposAction];
    [githubAlert addAction:cancelAction];
    
    // For iPad support
    if (githubAlert.popoverPresentationController) {
        githubAlert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    
    [self presentViewController:githubAlert animated:YES completion:nil];
}

- (void)openURL:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        [self showAlert:@"Error" message:@"Unable to open GitHub link. Please check your internet connection."];
    }
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)setupKeyboardDismissal {
    // Add tap gesture to dismiss keyboard when tapping outside text field
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tapGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGesture];
}

- (void)updateButtonStates {
    BOOL canAnalyze = !self.isDumping;
    BOOL canDump = !self.isDumping && self.hasAnalyzed && self.filteredClassNames.count > 0;
    BOOL canChangeOptions = !self.isDumping;
    
    // Update analyze button
    self.analyzeButton.enabled = canAnalyze;
    self.analyzeButton.alpha = canAnalyze ? 1.0 : 0.5;
    
    // Update dump button
    self.dumpButton.enabled = canDump;
    if (canDump) {
        self.dumpButton.backgroundColor = [UIColor systemGreenColor];
        self.dumpButton.alpha = 1.0;
    } else {
        self.dumpButton.backgroundColor = [UIColor systemGrayColor];
        self.dumpButton.alpha = 0.5;
    }
    
    // Update options switches
    self.addSymbolImageCommentsSwitch.enabled = canChangeOptions;
    self.stripSynthesizedSwitch.enabled = canChangeOptions;
    self.stripOverridesSwitch.enabled = canChangeOptions;
    self.stripProtocolConformanceSwitch.enabled = canChangeOptions;
    self.stripDuplicatesSwitch.enabled = canChangeOptions;
    
    // Update pattern fields
    self.includePatternField.enabled = canChangeOptions;
    self.excludePatternField.enabled = canChangeOptions;
}

- (void)setupUI {
    // Create scroll view
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];
    
    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];
    
    // Include patterns input
    UILabel *includeLabel = [[UILabel alloc] init];
    includeLabel.text = @"Include Patterns (comma-separated, e.g., 'UIKit*, NS*'):";
    includeLabel.font = [UIFont boldSystemFontOfSize:16];
    includeLabel.numberOfLines = 0;
    includeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:includeLabel];
    
    self.includePatternField = [[UITextField alloc] init];
    self.includePatternField.borderStyle = UITextBorderStyleRoundedRect;
    self.includePatternField.placeholder = @"Enter include patterns (optional)";
    self.includePatternField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.includePatternField addTarget:self action:@selector(patternFieldChanged) forControlEvents:UIControlEventEditingChanged];
    
    // Add Done button to keyboard toolbar for include field
    UIToolbar *includeKeyboardToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
    includeKeyboardToolbar.barStyle = UIBarStyleDefault;
    UIBarButtonItem *includeFlexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *includeDoneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard)];
    includeKeyboardToolbar.items = @[includeFlexSpace, includeDoneButton];
    [includeKeyboardToolbar sizeToFit];
    self.includePatternField.inputAccessoryView = includeKeyboardToolbar;
    
    [self.contentView addSubview:self.includePatternField];
    
    // Exclude patterns input
    UILabel *excludeLabel = [[UILabel alloc] init];
    excludeLabel.text = @"Exclude Patterns (comma-separated, e.g., 'Private*, *Internal*'):";
    excludeLabel.font = [UIFont boldSystemFontOfSize:16];
    excludeLabel.numberOfLines = 0;
    excludeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:excludeLabel];
    
    self.excludePatternField = [[UITextField alloc] init];
    self.excludePatternField.borderStyle = UITextBorderStyleRoundedRect;
    self.excludePatternField.placeholder = @"Enter exclude patterns (optional)";
    self.excludePatternField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.excludePatternField addTarget:self action:@selector(patternFieldChanged) forControlEvents:UIControlEventEditingChanged];
    
    // Add Done button to keyboard toolbar for exclude field
    UIToolbar *excludeKeyboardToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
    excludeKeyboardToolbar.barStyle = UIBarStyleDefault;
    UIBarButtonItem *excludeFlexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *excludeDoneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard)];
    excludeKeyboardToolbar.items = @[excludeFlexSpace, excludeDoneButton];
    [excludeKeyboardToolbar sizeToFit];
    self.excludePatternField.inputAccessoryView = excludeKeyboardToolbar;
    
    [self.contentView addSubview:self.excludePatternField];
    
    // Results label
    self.resultsLabel = [[UILabel alloc] init];
    self.resultsLabel.text = @"Tap 'Analyze' to see how many classes match your patterns";
    self.resultsLabel.font = [UIFont systemFontOfSize:14];
    self.resultsLabel.textColor = [UIColor secondaryLabelColor];
    self.resultsLabel.numberOfLines = 0;
    self.resultsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.resultsLabel];
    
    // Options section
    UILabel *optionsLabel = [[UILabel alloc] init];
    optionsLabel.text = @"Generation Options:";
    optionsLabel.font = [UIFont boldSystemFontOfSize:16];
    optionsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:optionsLabel];
    
    // Create option switches
    UIView *optionsContainer = [self createOptionsContainer];
    [self.contentView addSubview:optionsContainer];
    
    // Analyze button
    self.analyzeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.analyzeButton setTitle:@"Analyze Classes" forState:UIControlStateNormal];
    self.analyzeButton.backgroundColor = [UIColor systemBlueColor];
    [self.analyzeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.analyzeButton.layer.cornerRadius = 8;
    self.analyzeButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.analyzeButton addTarget:self action:@selector(analyzeClasses) forControlEvents:UIControlEventTouchUpInside];
    self.analyzeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.analyzeButton];
    
    // Dump button (initially grey and disabled)
    self.dumpButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.dumpButton setTitle:@"Dump Headers" forState:UIControlStateNormal];
    self.dumpButton.backgroundColor = [UIColor systemGrayColor];
    [self.dumpButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.dumpButton.layer.cornerRadius = 8;
    self.dumpButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.dumpButton addTarget:self action:@selector(dumpHeaders) forControlEvents:UIControlEventTouchUpInside];
    self.dumpButton.enabled = NO;
    self.dumpButton.alpha = 0.5;
    self.dumpButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.dumpButton];
    
    // Progress bar (initially hidden)
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressView.hidden = YES;
    [self.contentView addSubview:self.progressView];
    
    // Progress label (initially hidden)
    self.progressLabel = [[UILabel alloc] init];
    self.progressLabel.text = @"Preparing to dump headers...";
    self.progressLabel.font = [UIFont systemFontOfSize:14];
    self.progressLabel.textAlignment = NSTextAlignmentCenter;
    self.progressLabel.textColor = [UIColor secondaryLabelColor];
    self.progressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressLabel.hidden = YES;
    [self.contentView addSubview:self.progressLabel];
    
    // Cancel button (initially hidden)
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
    self.cancelButton.backgroundColor = [UIColor systemRedColor];
    [self.cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.cancelButton.layer.cornerRadius = 8;
    self.cancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.cancelButton addTarget:self action:@selector(cancelDump) forControlEvents:UIControlEventTouchUpInside];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.cancelButton.hidden = YES;
    [self.contentView addSubview:self.cancelButton];
    
    [self setupConstraints:includeLabel excludeLabel:excludeLabel optionsLabel:optionsLabel optionsContainer:optionsContainer];
}

- (void)patternFieldChanged {
    // Reset analysis when pattern changes
    self.hasAnalyzed = NO;
    self.filteredClassNames = nil;
    self.resultsLabel.text = @"Tap 'Analyze' to see how many classes match your patterns";
    self.resultsLabel.textColor = [UIColor secondaryLabelColor];
    [self updateButtonStates];
}

- (UIView *)createOptionsContainer {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSArray *optionTitles = @[
        @"Add Symbol Image Comments",
        @"Strip Synthesized Properties", 
        @"Strip Overrides",
        @"Strip Protocol Conformance",
        @"Strip Duplicates"
    ];
    
    NSArray *switches = @[
        self.addSymbolImageCommentsSwitch = [[UISwitch alloc] init],
        self.stripSynthesizedSwitch = [[UISwitch alloc] init],
        self.stripOverridesSwitch = [[UISwitch alloc] init],
        self.stripProtocolConformanceSwitch = [[UISwitch alloc] init],
        self.stripDuplicatesSwitch = [[UISwitch alloc] init]
    ];
    
    // Set default values to match the original implementation
    self.addSymbolImageCommentsSwitch.on = NO;
    self.stripSynthesizedSwitch.on = NO;
    self.stripOverridesSwitch.on = YES;
    self.stripProtocolConformanceSwitch.on = YES;
    self.stripDuplicatesSwitch.on = YES;
    
    UIView *previousView = nil;
    
    for (int i = 0; i < optionTitles.count; i++) {
        UIView *optionView = [[UIView alloc] init];
        optionView.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:optionView];
        
        UILabel *label = [[UILabel alloc] init];
        label.text = optionTitles[i];
        label.font = [UIFont systemFontOfSize:16];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [optionView addSubview:label];
        
        UISwitch *switchControl = switches[i];
        switchControl.translatesAutoresizingMaskIntoConstraints = NO;
        [optionView addSubview:switchControl];
        
        [NSLayoutConstraint activateConstraints:@[
            [optionView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [optionView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
            [optionView.heightAnchor constraintEqualToConstant:44],
            
            [label.leadingAnchor constraintEqualToAnchor:optionView.leadingAnchor],
            [label.centerYAnchor constraintEqualToAnchor:optionView.centerYAnchor],
            [label.trailingAnchor constraintLessThanOrEqualToAnchor:switchControl.leadingAnchor constant:-16],
            
            [switchControl.trailingAnchor constraintEqualToAnchor:optionView.trailingAnchor],
            [switchControl.centerYAnchor constraintEqualToAnchor:optionView.centerYAnchor]
        ]];
        
        if (previousView) {
            [optionView.topAnchor constraintEqualToAnchor:previousView.bottomAnchor].active = YES;
        } else {
            [optionView.topAnchor constraintEqualToAnchor:container.topAnchor].active = YES;
        }
        
        if (i == optionTitles.count - 1) {
            [optionView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor].active = YES;
        }
        
        previousView = optionView;
    }
    
    return container;
}

- (void)setupConstraints:(UILabel *)includeLabel excludeLabel:(UILabel *)excludeLabel optionsLabel:(UILabel *)optionsLabel optionsContainer:(UIView *)optionsContainer {
    [NSLayoutConstraint activateConstraints:@[
        // Scroll view
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        // Content view
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],
        
        // Include label
        [includeLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:20],
        [includeLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [includeLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        // Include field
        [self.includePatternField.topAnchor constraintEqualToAnchor:includeLabel.bottomAnchor constant:8],
        [self.includePatternField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.includePatternField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.includePatternField.heightAnchor constraintEqualToConstant:44],
        
        // Exclude label
        [excludeLabel.topAnchor constraintEqualToAnchor:self.includePatternField.bottomAnchor constant:16],
        [excludeLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [excludeLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        // Exclude field
        [self.excludePatternField.topAnchor constraintEqualToAnchor:excludeLabel.bottomAnchor constant:8],
        [self.excludePatternField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.excludePatternField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.excludePatternField.heightAnchor constraintEqualToConstant:44],
        
        // Results label
        [self.resultsLabel.topAnchor constraintEqualToAnchor:self.excludePatternField.bottomAnchor constant:8],
        [self.resultsLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.resultsLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        // Options label
        [optionsLabel.topAnchor constraintEqualToAnchor:self.resultsLabel.bottomAnchor constant:30],
        [optionsLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [optionsLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        // Options container
        [optionsContainer.topAnchor constraintEqualToAnchor:optionsLabel.bottomAnchor constant:16],
        [optionsContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [optionsContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        // Analyze button
        [self.analyzeButton.topAnchor constraintEqualToAnchor:optionsContainer.bottomAnchor constant:30],
        [self.analyzeButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.analyzeButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.analyzeButton.heightAnchor constraintEqualToConstant:50],
        
        // Dump button
        [self.dumpButton.topAnchor constraintEqualToAnchor:self.analyzeButton.bottomAnchor constant:16],
        [self.dumpButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.dumpButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.dumpButton.heightAnchor constraintEqualToConstant:50],
        
        // Progress view
        [self.progressView.topAnchor constraintEqualToAnchor:self.dumpButton.bottomAnchor constant:20],
        [self.progressView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.progressView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        // Progress label
        [self.progressLabel.topAnchor constraintEqualToAnchor:self.progressView.bottomAnchor constant:8],
        [self.progressLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.progressLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        // Cancel button
        [self.cancelButton.topAnchor constraintEqualToAnchor:self.progressLabel.bottomAnchor constant:16],
        [self.cancelButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.cancelButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.cancelButton.heightAnchor constraintEqualToConstant:50],
        [self.cancelButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-20]
    ]];
}

- (void)analyzeClasses {
    // Show progress and disable UI during analysis
    [self showAnalysisProgress];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *includePatterns = self.includePatternField.text;
        NSString *excludePatterns = self.excludePatternField.text;
        
        NSArray<NSString *> *allClassNames = [CDUtilities classNames];
        NSArray<NSString *> *filteredClassNames = [self filterClassNames:allClassNames withIncludePatterns:includePatterns excludePatterns:excludePatterns];
        
        // Create description of filters applied
        NSMutableString *filterDescription = [[NSMutableString alloc] init];
        
        NSArray<NSString *> *includeArray = [self parsePatterns:includePatterns];
        NSArray<NSString *> *excludeArray = [self parsePatterns:excludePatterns];
        
        if (includeArray.count > 0) {
            [filterDescription appendFormat:@"Include: %@", [includeArray componentsJoinedByString:@", "]];
        } else {
            [filterDescription appendString:@"Include: all classes"];
        }
        
        if (excludeArray.count > 0) {
            [filterDescription appendFormat:@" | Exclude: %@", [excludeArray componentsJoinedByString:@", "]];
        }
        
        // Update UI on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            self.filteredClassNames = filteredClassNames;
            self.resultsLabel.text = [NSString stringWithFormat:@"Found %lu classes\nFilters: %@", 
                                      (unsigned long)filteredClassNames.count, filterDescription];
            self.resultsLabel.textColor = [UIColor labelColor];
            
            self.hasAnalyzed = YES;
            [self hideAnalysisProgress];
            [self updateButtonStates];
            
            LogMessage(@"[DYDump] Analyzed filters - Include: %@, Exclude: %@. Found %lu matching classes", 
                      includeArray.count > 0 ? [includeArray componentsJoinedByString:@", "] : @"all", 
                      excludeArray.count > 0 ? [excludeArray componentsJoinedByString:@", "] : @"none", 
                      (unsigned long)filteredClassNames.count);
        });
    });
}

- (NSArray<NSString *> *)filterClassNames:(NSArray<NSString *> *)classNames withIncludePatterns:(NSString *)includePatterns excludePatterns:(NSString *)excludePatterns {
    NSMutableArray<NSString *> *filteredClasses = [classNames mutableCopy];
    
    // Process include patterns
    if (includePatterns && includePatterns.length > 0) {
        NSArray<NSString *> *includeArray = [self parsePatterns:includePatterns];
        if (includeArray.count > 0) {
            NSMutableArray<NSString *> *includedClasses = [[NSMutableArray alloc] init];
            
            for (NSString *pattern in includeArray) {
                NSString *trimmedPattern = [pattern stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (trimmedPattern.length > 0) {
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF LIKE[c] %@", trimmedPattern];
                    NSArray<NSString *> *matchedClasses = [classNames filteredArrayUsingPredicate:predicate];
                    [includedClasses addObjectsFromArray:matchedClasses];
                }
            }
            
            // Remove duplicates and update filtered classes
            filteredClasses = [[NSSet setWithArray:includedClasses].allObjects mutableCopy];
        }
    }
    
    // Process exclude patterns
    if (excludePatterns && excludePatterns.length > 0) {
        NSArray<NSString *> *excludeArray = [self parsePatterns:excludePatterns];
        
        for (NSString *pattern in excludeArray) {
            NSString *trimmedPattern = [pattern stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmedPattern.length > 0) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF LIKE[c] %@", trimmedPattern];
                NSArray<NSString *> *matchedClasses = [filteredClasses filteredArrayUsingPredicate:predicate];
                [filteredClasses removeObjectsInArray:matchedClasses];
            }
        }
    }
    
    // Sort results alphabetically
    return [filteredClasses sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (NSArray<NSString *> *)parsePatterns:(NSString *)patternString {
    if (!patternString || patternString.length == 0) {
        return @[];
    }
    
    // Split by comma and clean up whitespace
    NSArray<NSString *> *patterns = [patternString componentsSeparatedByString:@","];
    NSMutableArray<NSString *> *cleanPatterns = [[NSMutableArray alloc] init];
    
    for (NSString *pattern in patterns) {
        NSString *trimmed = [pattern stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length > 0) {
            [cleanPatterns addObject:trimmed];
        }
    }
    
    return cleanPatterns;
}

- (void)dumpHeaders {
    if (!self.filteredClassNames || self.filteredClassNames.count == 0) {
        [self showAlert:@"No Classes" message:@"Please analyze classes first."];
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Dump Headers" 
                                                                   message:[NSString stringWithFormat:@"This will dump %lu class headers to the Files app. Continue?", (unsigned long)self.filteredClassNames.count]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *dumpAction = [UIAlertAction actionWithTitle:@"Dump" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self performDump];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:dumpAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performDump {
    self.isDumping = YES;
    self.shouldCancelDump = NO;
    
    // Generate and store the current dump directory path
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *directoryName = [DYDumpHeaderDumper generateTimestampedDirectoryName];
    self.currentDumpDirectoryPath = [documentsPath stringByAppendingPathComponent:directoryName];
    
    // Show progress UI
    self.progressView.hidden = NO;
    self.progressLabel.hidden = NO;
    self.cancelButton.hidden = NO;
    
    self.progressView.progress = 0.0;
    self.progressLabel.text = @"Starting dump process...";
    
    [self updateButtonStates];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [DYDumpHeaderDumper dumpClassHeaders:self.filteredClassNames 
                                  withOptions:[self getCurrentOptions] 
                              progressCallback:^(NSInteger completed, NSInteger total, NSString *currentClass) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.shouldCancelDump) return;
                
                float progress = (float)completed / (float)total;
                self.progressView.progress = progress;
                self.progressLabel.text = [NSString stringWithFormat:@"Dumping %ld of %ld: %@", 
                                          (long)completed, (long)total, currentClass];
            });
        } 
                           cancelCallback:^BOOL{
            return self.shouldCancelDump;
        }
                         completionCallback:^(BOOL cancelled, NSInteger dumped, NSInteger skipped, NSInteger errors) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isDumping = NO;
                
                // Hide progress UI
                self.progressView.hidden = YES;
                self.progressLabel.hidden = YES;
                self.cancelButton.hidden = YES;
                
                [self updateButtonStates];
                
                if (cancelled) {
                    [self handleCancelledDump:dumped];
                } else {
                    [self showDumpCompleteAlertWithDumped:dumped skipped:skipped errors:errors directoryPath:self.currentDumpDirectoryPath];
                }
            });
        }];
    });
}

- (void)cancelDump {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cancel Dump" 
                                                                   message:@"Are you sure you want to cancel the dumping process?" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *continueAction = [UIAlertAction actionWithTitle:@"Continue Dumping" 
                                                             style:UIAlertActionStyleCancel 
                                                           handler:nil];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" 
                                                           style:UIAlertActionStyleDestructive 
                                                         handler:^(UIAlertAction * _Nonnull action) {
        self.shouldCancelDump = YES;
        self.progressLabel.text = @"Cancelling dump...";
    }];
    
    [alert addAction:continueAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)handleCancelledDump:(NSInteger)dumpedCount {
    if (dumpedCount == 0) {
        [self showAlert:@"Dump Cancelled" message:@"No files were dumped."];
        return;
    }
    
    NSString *message = [NSString stringWithFormat:@"Dump was cancelled. %ld files were dumped before cancellation.\n\nWould you like to delete the partially dumped headers?", (long)dumpedCount];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Dump Cancelled" 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *keepAction = [UIAlertAction actionWithTitle:@"Keep Files" 
                                                         style:UIAlertActionStyleDefault 
                                                       handler:^(UIAlertAction * _Nonnull action) {
        [self showCancelledDumpKeptAlert:dumpedCount];
    }];
    
    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"Delete Files" 
                                                           style:UIAlertActionStyleDestructive 
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self showDeletionProgress];
        [self deletePartialDump];
    }];
    
    [alert addAction:keepAction];
    [alert addAction:deleteAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showCancelledDumpKeptAlert:(NSInteger)dumpedCount {
    NSString *directoryName = [self.currentDumpDirectoryPath lastPathComponent];
    NSString *message = [NSString stringWithFormat:@"Kept %ld partially dumped headers.\n\nHeaders saved to: Documents/%@/", 
                        (long)dumpedCount, directoryName];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Files Kept" 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    // Share/Save button
    UIAlertAction *shareAction = [UIAlertAction actionWithTitle:@"Save to Files" 
                                                         style:UIAlertActionStyleDefault 
                                                       handler:^(UIAlertAction * _Nonnull action) {
        [self openFilesAppWithPath:self.currentDumpDirectoryPath];
    }];
    
    // OK button
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" 
                                                      style:UIAlertActionStyleCancel 
                                                    handler:nil];
    
    [alert addAction:shareAction];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showDeletionProgress {
    // Show progress UI while deleting
    self.progressView.hidden = NO;
    self.progressLabel.hidden = NO;
    self.progressView.progress = 0.0;
    self.progressLabel.text = @"Deleting files...";
    
    // Disable UI elements during deletion
    self.analyzeButton.enabled = NO;
    self.dumpButton.enabled = NO;
    self.includePatternField.enabled = NO;
    self.excludePatternField.enabled = NO;
    self.addSymbolImageCommentsSwitch.enabled = NO;
    self.stripSynthesizedSwitch.enabled = NO;
    self.stripOverridesSwitch.enabled = NO;
    self.stripProtocolConformanceSwitch.enabled = NO;
    self.stripDuplicatesSwitch.enabled = NO;
}

- (void)hideDeletionProgress {
    // Hide progress UI
    self.progressView.hidden = YES;
    self.progressLabel.hidden = YES;
    
    // Re-enable UI elements
    [self updateButtonStates];
}

- (void)showAnalysisProgress {
    // Show progress UI while analyzing
    self.progressView.hidden = NO;
    self.progressLabel.hidden = NO;
    self.progressView.progress = 0.0;
    self.progressLabel.text = @"Analyzing classes...";
    
    // Disable UI elements during analysis
    self.analyzeButton.enabled = NO;
    self.dumpButton.enabled = NO;
    self.includePatternField.enabled = NO;
    self.excludePatternField.enabled = NO;
    self.addSymbolImageCommentsSwitch.enabled = NO;
    self.stripSynthesizedSwitch.enabled = NO;
    self.stripOverridesSwitch.enabled = NO;
    self.stripProtocolConformanceSwitch.enabled = NO;
    self.stripDuplicatesSwitch.enabled = NO;
}

- (void)hideAnalysisProgress {
    // Hide progress UI
    self.progressView.hidden = YES;
    self.progressLabel.hidden = YES;
    
    // Re-enable UI elements
    [self updateButtonStates];
}

- (void)deletePartialDump {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        
        if (self.currentDumpDirectoryPath && [fileManager fileExistsAtPath:self.currentDumpDirectoryPath]) {
            [fileManager removeItemAtPath:self.currentDumpDirectoryPath error:&error];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideDeletionProgress];
                
                if (error) {
                    [self showAlert:@"Error" message:[NSString stringWithFormat:@"Failed to delete files: %@", error.localizedDescription]];
                } else {
                    [self showAlert:@"Files Deleted" message:@"All partially dumped headers have been deleted."];
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideDeletionProgress];
            });
        }
    });
}

- (NSDictionary *)getCurrentOptions {
    return @{
        @"addSymbolImageComments": @(self.addSymbolImageCommentsSwitch.isOn),
        @"stripSynthesized": @(self.stripSynthesizedSwitch.isOn),
        @"stripOverrides": @(self.stripOverridesSwitch.isOn),
        @"stripProtocolConformance": @(self.stripProtocolConformanceSwitch.isOn),
        @"stripDuplicates": @(self.stripDuplicatesSwitch.isOn)
    };
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showDumpCompleteAlertWithDumped:(NSInteger)dumped skipped:(NSInteger)skipped errors:(NSInteger)errors directoryPath:(NSString *)directoryPath {
    NSString *directoryName = [directoryPath lastPathComponent];
    NSString *message = [NSString stringWithFormat:@"Successfully dumped %ld headers!\nSkipped: %ld, Errors: %ld\n\nHeaders saved to: Documents/%@/", 
                        (long)dumped, (long)skipped, (long)errors, directoryName];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Dump Complete" 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    // Share/Save button
    UIAlertAction *shareAction = [UIAlertAction actionWithTitle:@"Save to Files" 
                                                         style:UIAlertActionStyleDefault 
                                                       handler:^(UIAlertAction * _Nonnull action) {
        [self openFilesAppWithPath:directoryPath];
    }];
    
    // OK button
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" 
                                                      style:UIAlertActionStyleCancel 
                                                    handler:nil];
    
    [alert addAction:shareAction];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openFilesAppWithPath:(NSString *)directoryPath {
    // Share the directory directly using UIActivityViewController
    [self presentDocumentInteractionControllerForPath:directoryPath];
}

- (void)presentDocumentInteractionControllerForPath:(NSString *)filePath {
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    
    if (@available(iOS 11.0, *)) {
        // Use UIActivityViewController for iOS 11+
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] 
                                               initWithActivityItems:@[fileURL] 
                                               applicationActivities:nil];
        
        // Configure for iPad
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            activityVC.popoverPresentationController.sourceView = self.view;
            activityVC.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, 
                                                                           self.view.bounds.size.height/2, 
                                                                           1, 1);
        }
        
        // Customize activities and handle cleanup
        activityVC.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
            if (completed) {
                NSLog(@"Successfully shared headers");
                // Clean up the original directory after successful share
                [self cleanupDirectoryAfterShare:filePath];
            } else if (activityError) {
                NSLog(@"Error sharing headers: %@", activityError.localizedDescription);
            }
        };
        
        [self presentViewController:activityVC animated:YES completion:nil];
    } else {
        // Fallback for older iOS versions
        UIDocumentInteractionController *documentController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
        documentController.delegate = self;
        
        // Store the file path for cleanup later
        objc_setAssociatedObject(documentController, "filePath", filePath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        if (![documentController presentOptionsMenuFromRect:CGRectMake(self.view.bounds.size.width/2, 
                                                                      self.view.bounds.size.height/2, 
                                                                      1, 1) 
                                                    inView:self.view 
                                                  animated:YES]) {
            [self showAlert:@"Unable to Share" 
                    message:@"Could not open sharing options. Headers are saved in the app's Documents directory."];
        }
    }
}

- (void)cleanupDirectoryAfterShare:(NSString *)directoryPath {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        
        if ([fileManager fileExistsAtPath:directoryPath]) {
            BOOL success = [fileManager removeItemAtPath:directoryPath error:&error];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    NSLog(@"Successfully cleaned up directory: %@", [directoryPath lastPathComponent]);
                } else {
                    NSLog(@"Failed to cleanup directory: %@", error.localizedDescription);
                }
            });
        }
    });
}

#pragma mark - UIDocumentInteractionControllerDelegate

- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application {
    // User successfully shared/saved the file
    NSString *filePath = objc_getAssociatedObject(controller, "filePath");
    if (filePath) {
        [self cleanupDirectoryAfterShare:filePath];
    }
}

- (void)documentInteractionControllerDidDismissOptionsMenu:(UIDocumentInteractionController *)controller {
    // Clean up associated object when done
    objc_setAssociatedObject(controller, "filePath", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


@end