#import "TXTTwitterCell.h"
#import <Preferences/PSSpecifier.h>

@interface TXTTwitterCell ()
@property (nonatomic, strong) UIImage *avatarImage;
@end

@implementation TXTTwitterCell {
    NSString *_user;
    UIImageView *_avatarImageView;
}

+ (NSString *)_urlForUsername:(NSString *)user {
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"aphelion://"]]) { // third-party Twitter client are no more
        return [@"aphelion://profile/" stringByAppendingString:user];
    } else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://"]]) {
        return [@"twitter://user?screen_name=" stringByAppendingString:user];
    } else {
        return [@"https://mobile.twitter.com/" stringByAppendingString:user];
    }
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];

    if (self) {
        _user = [specifier.properties[@"user"] copy];
        specifier.cellType = PSLinkCell;
        specifier.buttonAction = @selector(txt_openURL:);
        specifier.properties[@"url"] = [self.class _urlForUsername:_user];

        self.detailTextLabel.text = [@"@" stringByAppendingString:_user];
        self.detailTextLabel.textColor = [UIColor colorWithWhite:142.f / 255.f alpha:1];

        CGFloat size = 36.f;

        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, [UIScreen mainScreen].scale);
        specifier.properties[@"iconImage"] = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        UIView *avatarView = [[UIView alloc] initWithFrame:self.imageView.bounds];
        avatarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        avatarView.backgroundColor = [UIColor colorWithWhite:0.9f alpha:1];
        avatarView.userInteractionEnabled = NO;
        avatarView.clipsToBounds = YES;
        avatarView.layer.cornerRadius = size / 2;
        [self.imageView addSubview:avatarView];

        _avatarImageView = [[UIImageView alloc] initWithFrame:avatarView.bounds];
        _avatarImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _avatarImageView.alpha = 0;
        _avatarImageView.userInteractionEnabled = NO;
        _avatarImageView.layer.minificationFilter = kCAFilterTrilinear;
        [avatarView addSubview:_avatarImageView];

        [self loadAvatar];
    }

    return self;
}

- (UIImage *)avatarImage {
    return _avatarImageView.image;
}

- (void)setAvatarImage:(UIImage *)avatarImage {
    _avatarImageView.image = avatarImage;
    [UIView animateWithDuration:0.15 animations:^{
        self->_avatarImageView.alpha = 1;
    }];
}

- (void)loadAvatar {

    NSURL *twitterURL;

    if ([_user isEqualToString:@"ryannair05"]) {
        twitterURL = [NSURL URLWithString:@"https://pbs.twimg.com/profile_images/1161080936836018176/4GUKuGlb_200x200.jpg"];
    }
    else if ([_user isEqualToString:@"d3zb6z"]) {
        twitterURL = [NSURL URLWithString:@"https://pbs.twimg.com/profile_images/1124407974577917952/ioOk_7Ej_200x200.jpg"];
    }
    else {
        return;
    }

    [[[NSURLSession sharedSession]
        dataTaskWithURL:twitterURL
      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error != nil || data == nil) {
            return;
        }

        UIImage *image = [UIImage imageWithData:data];
        if (image == nil) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.avatarImage = image;
        });
    }] resume];
}

@end
