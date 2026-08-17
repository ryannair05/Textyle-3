export ARCHS = arm64 arm64e
export ADDITIONAL_CFLAGS = -fobjc-arc -fno-ptrauth-objc-class-ro

TARGET := iphone:clang:latest:15.0


FINALPACKAGE = 1

# THEOS_PACKAGE_SCHEME=rootless

SUBPROJECTS += preferences

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

TWEAK_NAME = Textyle
$(TWEAK_NAME)_FILES = \
	Tweak.xm \
	NSString+Stylize.m \
	TXTStyleCell.m \
	TXTStyleManager.m \
	TXTStyleSelectionController.m \
	TXTTextInput.m \
	$(wildcard Keyboard/*.xm)
$(TWEAK_NAME)_CFLAGS = -Wno-unguarded-availability-new
$(TWEAK_NAME)_FRAMEWORKS = UIKit

ifneq ($(TEXTYLE_SIMJECT),)
$(TWEAK_NAME)_CFLAGS += -DTEXTYLE_SIMJECT=1
$(TWEAK_NAME)_FILES += Simulator/TXTSimulatorSelfTests.m
endif

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

.PHONY: simject
simject:
	./scripts/run-simject.sh
