#ifdef THEOS_PACKAGE_INSTALL_PREFIX

#define kPrefsPath           @"/var/jb/var/mobile/Library/Preferences/com.ryannair05.textyle.plist"
#define kSystemStylesPath    @"/var/jb/Library/Application Support/Textyle/styles.plist"
#define kUserStylesPath      @"/var/jb/var/mobile/Library/Preferences/com.ryannair05.textyle.maps.plist"
#define kEnabledStylesPath   @"/var/jb/var/mobile/Library/Preferences/com.ryannair05.textyle.styles.plist"

#else

#define kPrefsPath           @"/var/mobile/Library/Preferences/com.ryannair05.textyle.plist"
#define kSystemStylesPath    @"/Library/Application Support/Textyle/styles.plist"
#define kUserStylesPath      @"/var/mobile/Library/Preferences/com.ryannair05.textyle.maps.plist"
#define kEnabledStylesPath   @"/var/mobile/Library/Preferences/com.ryannair05.textyle.styles.plist"

#endif

#ifdef THEOS_PACKAGE_INSTALL_PREFIX
#define kMenuIcon            @"/var/jb/Library/PreferenceBundles/Textyle.bundle/menuIcon.png"
#else
#define kMenuIcon            @"/Library/PreferenceBundles/Textyle.bundle/menuIcon.png"
#endif

#define kAccentColor         [UIColor colorWithRed:1.00 green:0.18 blue:0.33 alpha:1.0f]
#define kAccentColorAlpha    [UIColor colorWithRed:1.00 green:0.18 blue:0.33 alpha:0.85f]

#define kMenuWidth           230
#define kMenuHeight          315
#define kCornerRadius        12.0f
