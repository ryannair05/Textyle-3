#import "TXTRootListController.h"
#import "TXTPreferences.h"

#import <Preferences/PSSpecifier.h>
#include <spawn.h>
#include <sys/wait.h>

@interface TXTRootListController ()
@property (nonatomic, strong) UIView *headerView;
@end

@implementation TXTRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }

    return _specifiers;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithTitle:@"Respring"
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(respring:)];

        self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0,0,200,200)];
        UIImageView *headerImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0,0,200,200)];
        headerImageView.contentMode = UIViewContentModeScaleAspectFill;
        NSBundle *preferenceBundle = [NSBundle bundleWithPath:TXTPreferenceBundlePath];
        headerImageView.image = [UIImage imageNamed:@"banner"
                                          inBundle:preferenceBundle
                     compatibleWithTraitCollection:self.traitCollection];

        headerImageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.headerView addSubview:headerImageView];
    
        [NSLayoutConstraint activateConstraints:@[
            [headerImageView.topAnchor constraintEqualToAnchor:self.headerView.topAnchor],
            [headerImageView.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor],
            [headerImageView.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor],
            [headerImageView.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor],
        ]];
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.table.tableHeaderView = self.headerView;
}

- (void)respring:(id)sender {
    UIVisualEffectView* blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular]];
    [blurView setFrame:self.view.bounds];
    [blurView setAlpha:0.0];
    [[self view] addSubview:blurView];
    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        [blurView setAlpha:1.0];
    } completion:^(BOOL finished) {
        pid_t pid;
        int status;
        const char *executable = TXTRespringExecutablePath;
        char *const args[] = {(char *)executable, NULL};
        if (posix_spawn(&pid, executable, NULL, NULL, args, NULL) == 0) {
            waitpid(pid, &status, 0);
        }
    }];
}

- (void)txt_openURL:(PSSpecifier *)specifier {
    NSURL *url = [NSURL URLWithString:specifier.properties[@"url"]];

    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

@end
