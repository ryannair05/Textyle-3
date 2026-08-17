#pragma once

#import <UIKit/UIKit.h>

#if !defined(TEXTYLE_SIMJECT) && defined(THEOS_PACKAGE_INSTALL_PREFIX)
#import <rootless.h>
#endif

#if defined(TEXTYLE_SIMJECT)

#define kPrefsPath           @"/opt/simject/com.ryannair05.textyle.plist"
#define kSystemStylesPath    @"/opt/simject/Textyle.styles.plist"
#define kUserStylesPath      @"/opt/simject/Textyle.user-styles.plist"
#define kEnabledStylesPath   @"/opt/simject/Textyle.enabled-styles.plist"
#define kMenuIcon            @"/opt/simject/Textyle.menuIcon.png"

#else

#if defined(THEOS_PACKAGE_INSTALL_PREFIX)
#define kPrefsPath           ROOT_PATH_NS(@"/var/mobile/Library/Preferences/com.ryannair05.textyle.plist")
#define kUserStylesPath      ROOT_PATH_NS(@"/var/mobile/Library/Preferences/com.ryannair05.textyle.maps.plist")
#define kEnabledStylesPath   ROOT_PATH_NS(@"/var/mobile/Library/Preferences/com.ryannair05.textyle.styles.plist")
#define kSystemStylesPath    ROOT_PATH_NS(@"/Library/Application Support/Textyle/styles.plist")
#define kMenuIcon            ROOT_PATH_NS(@"/Library/PreferenceBundles/Textyle.bundle/menuIcon@2x.png")
#else
#define kPrefsPath           @"/var/mobile/Library/Preferences/com.ryannair05.textyle.plist"
#define kUserStylesPath      @"/var/mobile/Library/Preferences/com.ryannair05.textyle.maps.plist"
#define kEnabledStylesPath   @"/var/mobile/Library/Preferences/com.ryannair05.textyle.styles.plist"
#define kSystemStylesPath    @"/Library/Application Support/Textyle/styles.plist"
#define kMenuIcon            @"/Library/PreferenceBundles/Textyle.bundle/menuIcon@2x.png"
#endif

#endif

#define kTextyleStylesMenuIdentifier @"com.ryannair05.textyle.styles-menu"

#define kAccentColor         [UIColor colorWithRed:1.00 green:0.18 blue:0.33 alpha:1.0f]
#define kAccentColorAlpha    [UIColor colorWithRed:1.00 green:0.18 blue:0.33 alpha:0.85f]

#define kMenuWidth           260.0f
#define kMenuHeight          320.0f
#define kCornerRadius        22.0f
