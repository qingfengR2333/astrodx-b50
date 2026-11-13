export TARGET = iphone:clang:latest:15.0
# 只出 arm64：TrollFools 自带的 ldid 解析不了 arm64e / fat 包，会报
# "ldid: Unsupported Mach-O type"。AstroDX 本身是 arm64，单架构足够。
export ARCHS = arm64
export DEBUG = 0

TWEAK_NAME = AstroDXB50
AstroDXB50_FILES = Tweak.x B50Core.m Zip.m ImportPanel.m B50Image.m SettingsPanel.m ResourcePanel.m AboutPanel.m ChartDb.m ChartPanel.m ChartDetailSheet.m
AstroDXB50_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
AstroDXB50_FRAMEWORKS = UIKit Foundation UniformTypeIdentifiers
AstroDXB50_LDFLAGS = -lz

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
