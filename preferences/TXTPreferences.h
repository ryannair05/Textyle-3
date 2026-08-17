#pragma once

#import <Foundation/Foundation.h>

#if !defined(TEXTYLE_SIMJECT) && defined(THEOS_PACKAGE_INSTALL_PREFIX)
#import <rootless.h>
#endif

#if defined(TEXTYLE_SIMJECT)
#define TXTPreferencesDirectory @"/opt/simject"
#define TXTSystemStylesPath @"/opt/simject/Textyle.styles.plist"
#define TXTUserStylesPath @"/opt/simject/Textyle.user-styles.plist"
#define TXTPreferenceBundlePath @"/opt/simject/Textyle.bundle"
#define TXTRespringExecutablePath "/usr/bin/true"
#elif defined(THEOS_PACKAGE_INSTALL_PREFIX)
#define TXTPreferencesDirectory ROOT_PATH_NS(@"/var/mobile/Library/Preferences")
#define TXTSystemStylesPath ROOT_PATH_NS(@"/Library/Application Support/Textyle/styles.plist")
#define TXTUserStylesPath ROOT_PATH_NS(@"/var/mobile/Library/Preferences/com.ryannair05.textyle.maps.plist")
#define TXTPreferenceBundlePath ROOT_PATH_NS(@"/Library/PreferenceBundles/Textyle.bundle")
#define TXTRespringExecutablePath ROOT_PATH("/usr/bin/sbreload")
#else
#define TXTPreferencesDirectory @"/var/mobile/Library/Preferences"
#define TXTSystemStylesPath @"/Library/Application Support/Textyle/styles.plist"
#define TXTUserStylesPath @"/var/mobile/Library/Preferences/com.ryannair05.textyle.maps.plist"
#define TXTPreferenceBundlePath @"/Library/PreferenceBundles/Textyle.bundle"
#define TXTRespringExecutablePath "/usr/bin/sbreload"
#endif
