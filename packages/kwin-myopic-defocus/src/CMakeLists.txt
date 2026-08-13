cmake_minimum_required(VERSION 3.16)

project(kwin-myopic-defocus VERSION 0.1.0)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(QT_MIN_VERSION "6.6.0")
set(KF6_MIN_VERSION "6.0.0")

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH "${ECM_MODULE_PATH}")

include(KDECMakeSettings)
include(KDEInstallDirs)
include(FeatureSummary)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS
    Core
    Gui
    Widgets
    DBus
)

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    GlobalAccel
    WindowSystem
    Config
    ConfigWidgets
    CoreAddons
    I18n
    KCMUtils
)

find_package(KWin REQUIRED COMPONENTS kwineffects)
find_package(KWinDBusInterface CONFIG REQUIRED)
find_package(epoxy REQUIRED)

add_subdirectory(src)

feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)
