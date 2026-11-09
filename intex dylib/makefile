THEOS ?= /opt/theos
ARCHS := arm64
TARGET := iphone:clang:16.5:13.0
FINALPACKAGE = 1
FOR_RELEASE = 1
GAME_VARIANT ?= th
ifeq ($(filter $(GAME_VARIANT),th max),)
$(error GAME_VARIANT must be th or max)
endif
include $(THEOS)/makefiles/common.mk

TWEAK_NAME := iOSViet
iOSViet_USE_MODULES := 0

# THÊM ĐƯỜNG DẪN FILE CỤ THỂ VÀO ĐÂY ĐỂ CHẮC CHẮN NÓ ĐƯỢC BUILD
iOSViet_FILES := sources/StealthDylibInit.mm \
                 sources/InjectedMenuController.mm \
                 sources/_0xMO353DA.mm \
                 sources/_0xViSecureV28.m \
                 esp/drawing_view/_0xMU2872_.mm \
                 esp/drawing_view/_0xEPR2872_.mm \
                 esp/drawing_view/_0xEDR2862_.mm \
                 esp/drawing_view/FloatingFeatureControl.mm \
                 $(wildcard esp/drawing_view/*.mm esp/drawing_view/*.cpp esp/Core/*.mm esp/Core/*.cpp) \
                 esp/Core/AutoFireRemote.S esp/Core/GhostRemote.S esp/Core/PlayerModesRemote.S

iOSViet_CFLAGS += -DMIZZE_INJECTED=1 -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable -Wno-unused-value -Wno-module-import-in-extern-c -Wno-unknown-warning-option -Wno-unused-but-set-variable -fvisibility=hidden -fno-rtti -Os
iOSViet_CFLAGS += -I. -Iheaders -Isources -Ioxorany -Iobfuscation
iOSViet_CFLAGS += -DNOTIFY_DESTROY_HUD="\"com.dts.bugchi.hud.destroy\""
iOSViet_CFLAGS += -DPID_PATH="@\"/var/mobile/Library/Caches/com.dts.bugchi.pid\""
iOSViet_CFLAGS += -DOBFUSCATION_BUILD_SEED=0x4D495A5A4533ULL

ifeq ($(GAME_VARIANT),max)
iOSViet_CFLAGS += -DMIZZE_GAME_MAX=1 -DMIZZE_GAME_PROCESS_NAME="\"FreeFireMAX\""
else
iOSViet_CFLAGS += -DMIZZE_GAME_PROCESS_NAME="\"FreeFire\""
endif

iOSViet_CCFLAGS += -std=c++17
iOSViet_LDFLAGS += -Wl,-dead_strip_dylibs -Wl,-install_name,@rpath/libsubsystem.dylib sources/libAPIClient.a
iOSViet_FRAMEWORKS += CoreGraphics QuartzCore UIKit Security

include $(THEOS_MAKE_PATH)/tweak.mk

after-package::
	@mkdir -p packages
	@cp "$(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/MobileSubstrate/DynamicLibraries/iOSViet.dylib" packages/libsubsystem.dylib
