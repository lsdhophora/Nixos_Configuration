set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# Per the KWin documentation the library name is the plugin id
# ("myopicdefocus"), which is what KWin derives the effect id from.
add_library(myopicdefocus MODULE
    main.cpp
    myopicdefocus.cpp
    myopicdefocus.qrc
)

target_include_directories(myopicdefocus PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(myopicdefocus PRIVATE
    KWin::kwin
    KF6::GlobalAccel
    KF6::WindowSystem
    KF6::ConfigCore
    epoxy::epoxy
)

install(TARGETS myopicdefocus
        DESTINATION ${KDE_INSTALL_PLUGINDIR}/kwin/effects/plugins)

install(FILES metadata.json
        DESTINATION ${KDE_INSTALL_PLUGINDIR}/kwin/effects/plugins)

#######################################
# Configuration module (System Settings -> Desktop Effects -> Configure)
set(myopicdefocus_config_SRCS
    kcm/myopicdefocus_config.cpp
    kcm/myopicdefocus_config.h
)

ki18n_wrap_ui(myopicdefocus_config_SRCS kcm/myopicdefocus_config.ui)
kconfig_add_kcfg_files(myopicdefocus_config_SRCS myopicdefocusconfig.kcfgc)
qt_add_dbus_interface(myopicdefocus_config_SRCS ${KWIN_EFFECTS_INTERFACE} kwineffects_interface)

add_library(kwin_effect_myopicdefocus_config MODULE ${myopicdefocus_config_SRCS})

target_include_directories(kwin_effect_myopicdefocus_config PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(kwin_effect_myopicdefocus_config PRIVATE
    KF6::KCMUtils
    KF6::CoreAddons
    KF6::I18n
    KF6::ConfigWidgets
    Qt6::DBus
    Qt6::Widgets
)

# K_PLUGIN_CLASS cannot define a class with a qualified name; give the
# plugin factory an explicit unqualified name (matches the .so basename).
target_compile_definitions(kwin_effect_myopicdefocus_config PRIVATE
    KPLUGINFACTORY_PLUGIN_CLASS_INTERNAL_NAME=kwin_effect_myopicdefocus_config
)

install(TARGETS kwin_effect_myopicdefocus_config
        DESTINATION ${KDE_INSTALL_PLUGINDIR}/kwin/effects/configs)

install(FILES kcm/metadata.json
        DESTINATION ${KDE_INSTALL_PLUGINDIR}/kwin/effects/configs)
