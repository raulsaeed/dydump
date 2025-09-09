TARGET := iphone:clang:latest:14.5
THEOS_DEVICE_IP = 192.168.100.35
THEOS_DEVICE_USER = root

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = dydump

$(TWEAK_NAME)_FILES = Tweak.x \
	IOSLogger.m DYDumpHeaderDumper.m DYDumpHeaderDumperUI.m \
	$(wildcard ClassDumpRuntime/ClassDump/Models/*.m) \
		$(wildcard ClassDumpRuntime/ClassDump/Models/ParseTypes/*.m) \
		$(wildcard ClassDumpRuntime/ClassDump/Models/Reflections/*.m) \
		$(wildcard ClassDumpRuntime/ClassDump/Services/*.m)

$(TWEAK_NAME)_CFLAGS = -fobjc-arc -I/Users/raul/Developer/Theos/dydump/ClassDumpRuntime/Sources/ClassDumpRuntime/include
$(TWEAK_NAME)_CFLAGS += -fobjc-arc -Wno-deprecated-declarations -Wno-nullability-completeness  -Wno-arc-performSelector-leaks
$(TWEAK_NAME)_LIBRARIES = c++abi substrate


include $(THEOS_MAKE_PATH)/tweak.mk
