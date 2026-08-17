#import "TXTStyleCell.h"
#import "TXTConstants.h"

@implementation TXTStyleCell

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        _label = [[UILabel alloc] init];
        [_label setTextColor:[UIColor labelColor]];
        [_label setTextAlignment:NSTextAlignmentCenter];
        [_label setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]];
        _label.adjustsFontForContentSizeCategory = YES;
        _label.accessibilityIdentifier =
            @"com.ryannair05.textyle.style-selector.label";

        [self.contentView addSubview:_label];

        _label.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [_label.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor
                                                 constant:16.0],
            [_label.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_label.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor
                                                   constant:-16.0],
        ]];

        self.isAccessibilityElement = YES;
    }

    return self;
}

- (void)updateConfigurationUsingState:(UICellConfigurationState *)state {
    [super updateConfigurationUsingState:state];

    BOOL emphasized = state.isSelected || state.isHighlighted;
    self.backgroundColor = emphasized
        ? kAccentColor
        : UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.label.textColor = emphasized ? UIColor.whiteColor : UIColor.labelColor;

    UIAccessibilityTraits traits = UIAccessibilityTraitButton;
    if (state.isSelected) {
        traits |= UIAccessibilityTraitSelected;
    }
    self.accessibilityTraits = traits;
}

@end
