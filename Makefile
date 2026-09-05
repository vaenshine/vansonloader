TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VansonLoader
VANSONLOADER_VERSION := $(shell awk -F': ' '/^Version:/ {print $$2; exit}' control)

# 从 control 读取版本号，额外生成带版本的 dylib
after-VansonLoader-all::
	@VER=$$(grep -E '^Version:' control | cut -d' ' -f2); \
	if [ -f "$(THEOS_OBJ_DIR)/VansonLoader.dylib" ] && [ -n "$$VER" ]; then \
		cp "$(THEOS_OBJ_DIR)/VansonLoader.dylib" "$(THEOS_OBJ_DIR)/VansonLoader_v$${VER}.dylib"; \
		echo "==> Output: VansonLoader_v$${VER}.dylib"; \
	fi

# L2.3 模块化源文件 (VL 前缀)
VansonLoader_FILES = \
	Tweak.xm \
	src/Core/VLCore.cpp \
	src/Core/VLMemCore.cpp \
	src/Core/VLDebugCore.cpp \
	src/Core/VLDisasm.cpp \
	src/Models/VLModItem.m \
	src/Models/VLScriptItem.m \
	src/Engine/VLModEngine.mm \
	src/Engine/VLMemEngine.mm \
	src/Engine/VLModParser.m \
	src/Engine/VLScriptManager.mm \
	src/Engine/VLScriptEngine.mm \
	src/Engine/VLDebugEngine.mm \
	src/Utils/VLCrypto.mm \
	src/Utils/VLLocalization.mm \
	src/Utils/VLIconManager.mm \
	src/UI/VLModCell.m \
	src/UI/VLPanel.m \
	src/UI/VLPanelNav.m \
	src/UI/VLPanelMemory.m \
	src/UI/VLPanelToolbox.m \
	src/UI/VLOverlayWindow.m \
	src/UI/VLTools.m \
	src/UI/VLAbout.m \
	src/UI/VLFloatingButton.m \
	src/UI/VLItemEditor.m \
	src/UI/VLMemorySearch.m \
	src/UI/VLMemoryBrowser.m \
	src/UI/VLStringEditorViewController.m \
	src/UI/VLStringMemorySession.m \
	src/UI/VLToolbox.m \
	src/UI/VLMemResults.m \
	src/UI/VLWatchOverlay.m \
	src/UI/VLDockBadge.m \
	src/UI/VLFileBrowser.m \
	src/UI/VLPanelSizeHelper.m \
	src/Utils/Lang/VLLangManager.cpp \
	src/Utils/Lang/VLLang_EN.cpp \
	src/Utils/Lang/VLLang_CN.cpp \
	src/Utils/Lang/VLLang_TW.cpp \
	src/Utils/Lang/VLLang_JA.cpp \
	src/Utils/Lang/VLLang_KO.cpp \
	src/Utils/Lang/VLLang_RU.cpp \
	src/Utils/Lang/VLLang_ES.cpp \
	src/Utils/Lang/VLLang_VI.cpp \
	src/Utils/Lang/VLLang_TH.cpp \
	src/Utils/Lang/VLLang_PT.cpp \
	src/Utils/Lang/VLLang_FR.cpp \
	src/Utils/Lang/VLLang_DE.cpp \
	src/Utils/Lang/VLLang_AR.cpp

VansonLoader_FRAMEWORKS = UIKit Foundation MobileCoreServices UniformTypeIdentifiers AVFoundation Security JavaScriptCore
VansonLoader_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR) -DVERSION_STRING=@\"$(VANSONLOADER_VERSION)\"
VansonLoader_CXXFLAGS = -std=c++17 -fvisibility=hidden -fvisibility-inlines-hidden
VansonLoader_CCFLAGS = -std=c++17

include $(THEOS_MAKE_PATH)/tweak.mk
