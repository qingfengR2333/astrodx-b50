export TARGET = iphone:clang:latest:15.0
export ARCHS = arm64 arm64e
export DEBUG = 0

TWEAK_NAME = AstroDXB50
AstroDXB50_FILES = Tweak.x B50Core.m
AstroDXB50_CFLAGS = -fobjc-arc
AstroDXB50_FRAMEWORKS = UIKit Foundation
AstroDXB50_LDFLAGS = -lz

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
