THEOS_DEVICE_IP = 192.168.1.229

export ARCHS = arm64 arm64e

TARGET := iphone:clang:15.2:15.0

# GO_EASY_ON_ME = 1

FINALPACKAGE = 1

# THEOS_PACKAGE_SCHEME=rootless

SUBPROJECTS += preferences

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

TWEAK_NAME = Textyle
$(TWEAK_NAME)_FILES = $(wildcard *.m *.xm)
ADDITIONAL_OBJCFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
