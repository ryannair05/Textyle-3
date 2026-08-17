#import "TXTStylesController.h"
#import "TXTPreferences.h"

#import <Preferences/PSSpecifier.h>

@implementation TXTStylesController {
    NSArray *styles;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Edit Styles";
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [NSMutableArray array];

        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Installed Styles"];
        [group setProperty:[NSString stringWithFormat:@"To add or modify styles, edit %@.",
                                                      TXTUserStylesPath]
                    forKey:@"footerText"];

        [specifiers addObject:group];

        [self loadStyles];

        for (NSDictionary *style in styles) {
            PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:style[@"label"]
                                                               target:self
                                                                  set:@selector(setPreferenceValue:specifier:)
                                                                  get:@selector(readPreferenceValue:)
                                                               detail:Nil
                                                                 cell:PSSwitchCell
                                                                 edit:Nil];

            [item setProperty:style[@"name"] forKey:@"key"];
            [item setProperty:@YES forKey:@"enabled"];
            [item setProperty:@YES forKey:@"default"];
            [item setProperty:@"com.ryannair05.textyle.styles" forKey:@"defaults"];
            [item setProperty:@"com.ryannair05.textyle.styles/enabledStyles" forKey:@"PostNotification"];
            [specifiers addObject:item];
        }

        _specifiers = [specifiers copy];
    }

    return _specifiers;
}

- (void)loadStyles {
    if (![[NSFileManager defaultManager] fileExistsAtPath:TXTUserStylesPath]) {
        NSArray *installedStyles = [NSArray arrayWithContentsOfFile:TXTSystemStylesPath];
        styles = [installedStyles isKindOfClass:[NSArray class]] ? installedStyles : @[];
        if (styles.count > 0) {
            [styles writeToFile:TXTUserStylesPath atomically:YES];
        }
    } else {
        NSArray *userStyles = [NSArray arrayWithContentsOfFile:TXTUserStylesPath];
        styles = [userStyles isKindOfClass:[NSArray class]] ? userStyles : @[];
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.table setEditing:editing animated:animated];

    if (!editing && [styles writeToFile:TXTUserStylesPath atomically:YES]) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR("com.ryannair05.textyle.styles/enabledStyles"),
            NULL,
            NULL,
            YES);
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableview shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    NSDictionary *item = [styles objectAtIndex:sourceIndexPath.row];
    NSMutableArray *stylesEdited = [styles mutableCopy];

    [stylesEdited removeObjectAtIndex:sourceIndexPath.row];
    [stylesEdited insertObject:item atIndex:destinationIndexPath.row];

    styles = stylesEdited;
}

@end
