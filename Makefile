# TYPE=0: rootfull, TYPE=1: rootless, TYPE=2: RootHide
TYPE ?= 1
DEBUG = 0
FINALPACKAGE = 1

ifeq ($(TYPE),0)
ARCHS ?= arm64
TARGET = iphone:clang:16.5:13.0
THEOS_PACKAGE_SCHEME =
else ifeq ($(TYPE),1)
ARCHS ?= arm64 arm64e
TARGET = iphone:clang:16.5:14.0
THEOS_PACKAGE_SCHEME = rootless
else ifeq ($(TYPE),2)
ARCHS ?= arm64 arm64e
TARGET = iphone:clang:16.5:14.0
THEOS_PACKAGE_SCHEME = roothide
else
$(error Unsupported TYPE '$(TYPE)'; use 0, 1 or 2)
endif

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HelloWorld
HelloWorld_FILES = Tweak.xm
HelloWorld_CFLAGS = -fobjc-arc
HelloWorld_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
