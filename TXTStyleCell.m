#import "TXTStyleCell.h"
#import "TXTStyleManager.h"

@implementation TXTStyleCell

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        _label = [[UILabel alloc] init];
        [_label setTextColor:[UIColor labelColor]];
        [_label setTextAlignment:NSTextAlignmentCenter];
        [_label setFont:[UIFont systemFontOfSize:16]];

        [self.contentView addSubview:_label];

        [_label setTranslatesAutoresizingMaskIntoConstraints: NO];
        [_label.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor].active = YES;
        [_label.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor].active = YES;
    }

    return self;
}

- (void)updateConfigurationUsingState:(UICellConfigurationState *)state {
    [super updateConfigurationUsingState:state];
    
    if (state.isSelected) {
        [[TXTStyleManager sharedManager] selectStyle:_label.text];

        [UIView animateWithDuration:0.25
               animations:^{
                    [self setBackgroundColor:[UIColor colorWithRed:1.00 green:0.18 blue:0.33 alpha:1.0f]];
               }
          ];
    }
    else {
        [self setBackgroundColor:[UIColor clearColor]];
    }
    
}

@end
