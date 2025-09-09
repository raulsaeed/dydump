TARGET := iphone:clang:latest:14.5
THEOS_DEVICE_IP = 192.168.100.35
THEOS_DEVICE_USER = root
INSTALL_TARGET_PROCESSES = TikTok

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = dydump

$(TWEAK_NAME)_FILES = Tweak.x \
	IOSLogger.m \
	DYDumpHeaderDumper.m \
	DYDumpHeaderDumperUI.m \
	ClassDumpRuntime/ClassDump/Models/CDSemanticString.m \
	ClassDumpRuntime/ClassDump/Models/CDVariableModel.m \
	ClassDumpRuntime/ClassDump/Models/CDGenerationOptions.m \
	ClassDumpRuntime/ClassDump/Models/NSArray+CDFiltering.m \
	ClassDumpRuntime/ClassDump/Models/ParseTypes/CDBlockType.m \
	ClassDumpRuntime/ClassDump/Models/ParseTypes/CDBitFieldType.m \
	ClassDumpRuntime/ClassDump/Models/ParseTypes/CDObjectType.m \
	ClassDumpRuntime/ClassDump/Models/ParseTypes/CDArrayType.m \
	ClassDumpRuntime/ClassDump/Models/ParseTypes/CDParseType.m \
	ClassDumpRuntime/ClassDump/Models/ParseTypes/CDPointerType.m \
	ClassDumpRuntime/ClassDump/Models/ParseTypes/CDRecordType.m \
	ClassDumpRuntime/ClassDump/Models/ParseTypes/CDPrimitiveType.m \
	ClassDumpRuntime/ClassDump/Models/Reflections/CDClassModel.m \
	ClassDumpRuntime/ClassDump/Models/Reflections/CDPropertyModel.m \
	ClassDumpRuntime/ClassDump/Models/Reflections/CDIvarModel.m \
	ClassDumpRuntime/ClassDump/Models/Reflections/CDPropertyAttribute.m \
	ClassDumpRuntime/ClassDump/Models/Reflections/CDMethodModel.m \
	ClassDumpRuntime/ClassDump/Models/Reflections/CDProtocolModel.m \
	ClassDumpRuntime/ClassDump/Models/Reflections/CDProtocolModel+Conformance.m \
	ClassDumpRuntime/ClassDump/Services/CDTypeParser.m \
	ClassDumpRuntime/ClassDump/Services/CDUtilities.m

$(TWEAK_NAME)_CFLAGS = -fobjc-arc -I/Users/raul/Developer/Theos/dydump/ClassDumpRuntime/Sources/ClassDumpRuntime/include
$(TWEAK_NAME)_CFLAGS += -fobjc-arc -Wno-deprecated-declarations -Wno-nullability-completeness  -Wno-arc-performSelector-leaks
$(TWEAK_NAME)_LIBRARIES = c++abi substrate
include $(THEOS_MAKE_PATH)/tweak.mk
