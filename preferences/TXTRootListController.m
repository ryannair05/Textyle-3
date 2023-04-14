#import "TXTRootListController.h"
#import <Preferences/PSSpecifier.h>
#include <spawn.h>

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
        self.respringButton = [[UIBarButtonItem alloc] initWithTitle:@"Respring"
                                    style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(respring:)];
        self.navigationItem.rightBarButtonItem = self.respringButton;

        self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0,0,200,200)];
        UIImageView *headerImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0,0,200,200)];
        headerImageView.contentMode = UIViewContentModeScaleAspectFill;
        #ifdef THEOS_PACKAGE_INSTALL_PREFIX
        headerImageView.image = [UIImage imageWithContentsOfFile:@"/var/jb/Library/PreferenceBundles/Textyle.bundle/banner.png"];;
        #else
        headerImageView.image = [UIImage imageWithContentsOfFile:@"/Library/PreferenceBundles/Textyle.bundle/banner.png"];
        #endif

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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    tableView.tableHeaderView = self.headerView;
    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
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
        const char* args[] = {"sbreload", NULL};
        #ifdef THEOS_PACKAGE_INSTALL_PREFIX
        posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char* const*)args, NULL);
        #else
        posix_spawn(&pid, "/usr/bin/sbreload", NULL, NULL, (char* const*)args, NULL);
        #endif
        waitpid(pid, &status, WEXITED);
    }];
}

- (void)txt_openURL:(PSSpecifier *)specifier {
    NSURL *url = [NSURL URLWithString:specifier.properties[@"url"]];

    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

@end
