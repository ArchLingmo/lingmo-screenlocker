# Lingmo lock screen for KWin's screen locker (Wayland session).
# kscreenlocker_greet 6.8 loads lockscreen/LockScreen.qml from the Plasma/Shell
# package named by plasmashellrc [Shell] ShellPackage; it must say
# X-Plasma-APIVersion 2 or the greeter calls it outdated.
set(LINGMO_LOCKSCREEN_PACKAGE com.lingmo.desktop)

install(FILES metadata.json
        DESTINATION ${CMAKE_INSTALL_DATADIR}/plasma/shells/${LINGMO_LOCKSCREEN_PACKAGE})
install(DIRECTORY contents
        DESTINATION ${CMAKE_INSTALL_DATADIR}/plasma/shells/${LINGMO_LOCKSCREEN_PACKAGE})

# Defaults for the Lingmo session only (its XDG_CONFIG_DIRS starts with this dir)
install(FILES config/plasmashellrc config/kscreenlockerrc
        DESTINATION ${CMAKE_INSTALL_DATADIR}/lingmo/xdg)

# The QML uses i18nd("lingmo-lockscreen", ...) (the greeter has KI18n)
find_program(MSGFMT_EXECUTABLE msgfmt REQUIRED)
file(GLOB PO_FILES ${CMAKE_CURRENT_SOURCE_DIR}/po/*.po)
foreach(po_file ${PO_FILES})
    get_filename_component(lang ${po_file} NAME_WE)
    set(mo_file ${CMAKE_CURRENT_BINARY_DIR}/${lang}/lingmo-lockscreen.mo)
    add_custom_command(OUTPUT ${mo_file}
                       COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/${lang}
                       COMMAND ${MSGFMT_EXECUTABLE} --check -o ${mo_file} ${po_file}
                       DEPENDS ${po_file})
    list(APPEND MO_FILES ${mo_file})
    install(FILES ${mo_file} DESTINATION ${CMAKE_INSTALL_LOCALEDIR}/${lang}/LC_MESSAGES)
endforeach()
add_custom_target(lockscreen-translations ALL DEPENDS ${MO_FILES} SOURCES ${PO_FILES})
