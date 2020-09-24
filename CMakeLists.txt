project(os-autoinst CXX)
cmake_minimum_required(VERSION 3.3.0)

# list non-C++ source files
set(DOC_FILES
    doc/architecture.md
    doc/backend_vars.asciidoc
    doc/backends.md
    doc/memorydumps.asciidoc
    doc/networking.md
)
set(PERL_FILES
    lib/autotest.pm
    lib/backend/amt.pm
    lib/backend/baseclass.pm
    lib/backend/console_proxy.pm
    lib/backend/driver.pm
    lib/backend/generalhw.pm
    lib/backend/ikvm.pm
    lib/backend/ipmi.pm
    lib/backend/null.pm
    lib/backend/pvm_hmc.pm
    lib/backend/pvm.pm
    lib/backend/qemu.pm
    lib/backend/s390x.pm
    lib/backend/spvm.pm
    lib/backend/svirt.pm
    lib/backend/virt.pm
    lib/basetest.pm
    lib/bmwqemu.pm
    lib/commands.pm
    lib/consoles/amtSol.pm
    lib/consoles/console.pm
    lib/consoles/ipmiSol.pm
    lib/consoles/localXvnc.pm
    lib/consoles/network_console.pm
    lib/consoles/remoteVnc.pm
    lib/consoles/s3270.pm
    lib/consoles/serial_screen.pm
    lib/consoles/sshIucvconn.pm
    lib/consoles/ssh_screen.pm
    lib/consoles/sshVirtsh.pm
    lib/consoles/sshVirtshSUT.pm
    lib/consoles/sshX3270.pm
    lib/consoles/sshXtermIPMI.pm
    lib/consoles/sshXtermVt.pm
    lib/consoles/ttyConsole.pm
    lib/consoles/virtio_terminal.pm
    lib/consoles/vnc_base.pm
    lib/consoles/VNC.pm
    lib/distribution.pm
    lib/lockapi.pm
    lib/mmapi.pm
    lib/myjsonrpc.pm
    lib/needle.pm
    lib/ocr.pm
    lib/OpenQA/Benchmark/Stopwatch.pm
    lib/OpenQA/Commands.pm
    lib/OpenQA/Exceptions.pm
    lib/OpenQA/Isotovideo/CommandHandler.pm
    lib/OpenQA/Isotovideo/Interface.pm
    lib/OpenQA/Isotovideo/NeedleDownloader.pm
    lib/OpenQA/Isotovideo/Utils.pm
    lib/OpenQA/Qemu/BlockDevConf.pm
    lib/OpenQA/Qemu/BlockDev.pm
    lib/OpenQA/Qemu/ControllerConf.pm
    lib/OpenQA/Qemu/DriveController.pm
    lib/OpenQA/Qemu/DriveDevice.pm
    lib/OpenQA/Qemu/DrivePath.pm
    lib/OpenQA/Qemu/MutParams.pm
    lib/OpenQA/Qemu/PFlashDevice.pm
    lib/OpenQA/Qemu/Proc.pm
    lib/OpenQA/Qemu/SnapshotConf.pm
    lib/OpenQA/Qemu/Snapshot.pm
    lib/OpenQA/Test/RunArgs.pm
    lib/osutils.pm
    lib/signalblocker.pm
    lib/testapi.pm
)
set(MISC_FILES
    consoles/icewm.cfg
    crop.py
    dmidata/dell_e6330/smbios_type_1.bin
    dmidata/dell_e6330/smbios_type_2.bin
    dmidata/dell_e6330/smbios_type_3.bin
    dmidata/dump
)

# determine install directories
# note: Not using ${CMAKE_INSTALL_LIBDIR} here because this seems always lib in our packaging (and
#       never lib64) regardless of the architecture.
include(GNUInstallDirs)
set(OS_AUTOINST_DATA_DIR "lib/os-autoinst"
    CACHE STRING "directory to install os-autoinst internal Perl modules and misc files to")
set(OS_AUTOINST_DOC_DIR "${CMAKE_INSTALL_DATAROOTDIR}/doc/packages/os-autoinst"
    CACHE STRING "directory to install documentation to")
set(SYSTEMD_SERVICE_DIR "lib/systemd/system"
    CACHE STRING "directory to install systemd service files to")

# common dependency lookup
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake;${CMAKE_MODULE_PATH}")
include(pkg-config)
find_package(OpenCV REQUIRED)

# build and install tools/libraries in sub directories
add_subdirectory(debugviewer)
add_subdirectory(snd2png)
add_subdirectory(ppmclibs)
add_subdirectory(doc)
add_subdirectory(systemd)

# build and install videoencoder
add_executable(videoencoder videoencoder.cpp)
target_use_pkg_config_module(videoencoder "theoraenc>=1.1")
install(TARGETS videoencoder RUNTIME DESTINATION "${OS_AUTOINST_DATA_DIR}")

# allow symlinking created executables into source directory
# note: This target is supposed to be used for making a development environment. The symlinks will
#       allow isotovideo to find all native executables created by this build.
get_filename_component(SRC_DIR "${CMAKE_SOURCE_DIR}" REALPATH)
get_filename_component(BIN_DIR "${CMAKE_BINARY_DIR}" REALPATH)
if (NOT SRC_DIR STREQUAL BIN_DIR)
    set(OUT_OF_SOURCE_TREE_BUILD_COMMANDS
        COMMAND ln -fs $<TARGET_FILE:videoencoder> "${CMAKE_CURRENT_SOURCE_DIR}/videoencoder"
        COMMAND ln -fs $<TARGET_FILE:snd2png> "${CMAKE_CURRENT_SOURCE_DIR}/snd2png/snd2png"
        COMMAND ln -fs $<TARGET_FILE:debugviewer> "${CMAKE_CURRENT_SOURCE_DIR}/debugviewer/debugviewer"
    )
endif ()
add_custom_target(
    symlinks
    COMMENT "Symlinking created executables into source directory"
    COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/ppmclibs/blib/arch/auto/tinycv"
    COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/ppmclibs/blib/lib"
    COMMAND ln -fs "../../tinycv.pm" "${CMAKE_CURRENT_SOURCE_DIR}/ppmclibs/blib/lib/tinycv.pm"
    COMMAND ln -fs $<TARGET_FILE:tinycv> "${CMAKE_CURRENT_SOURCE_DIR}/ppmclibs/blib/arch/auto/tinycv/tinycv.so"
    ${OUT_OF_SOURCE_TREE_BUILD_COMMANDS}
)
add_dependencies(symlinks videoencoder snd2png debugviewer tinycv)

# create installable versions of isotovideo and cv.pm
add_custom_command(
    COMMENT "Make directory to store intermediate files for install target"
    COMMAND mkdir -p "${CMAKE_CURRENT_BINARY_DIR}/install-target"
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/install-target"
)
add_custom_command(
    COMMENT "Make install version of isotovideo"
    COMMAND
        sed -e "\"s,\\$$installprefix = undef\;,\\$$installprefix = '${CMAKE_INSTALL_PREFIX}/${OS_AUTOINST_DATA_DIR}'\;,\""
        "${CMAKE_CURRENT_SOURCE_DIR}/bin/isotovideo" > "${CMAKE_CURRENT_BINARY_DIR}/install-target/bin/isotovideo"
    DEPENDS "bin/isotovideo" "CMakeLists.txt" "${CMAKE_CURRENT_BINARY_DIR}/install-target"
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/install-target/bin/isotovideo"
)
add_custom_command(
    COMMENT "Make install version of cv.pm"
    COMMAND
        sed -e "\"s,\\$$sysdir = undef\;,\\$$sysdir = '${CMAKE_INSTALL_PREFIX}/${OS_AUTOINST_DATA_DIR}'\;,\""
        "${CMAKE_CURRENT_SOURCE_DIR}/lib/cv.pm" > "${CMAKE_CURRENT_BINARY_DIR}/install-target/lib/cv.pm"
    DEPENDS "lib/cv.pm" "CMakeLists.txt" "${CMAKE_CURRENT_BINARY_DIR}/install-target"
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/install-target/lib/cv.pm"
)
add_custom_target(generate-install-versions ALL
    COMMENT "Generate install version of isotovideo and cv.pm"
    DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/install-target/bin/isotovideo" "${CMAKE_CURRENT_BINARY_DIR}/install-target/lib/cv.pm"
)

# install non-C++ files
set(EXECUTABLE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
install(
    FILES "${CMAKE_CURRENT_BINARY_DIR}/install-target/bin/isotovideo"
    DESTINATION "${CMAKE_INSTALL_BINDIR}"
    PERMISSIONS ${EXECUTABLE_PERMISSIONS}
)
foreach (FILE README.asciidoc COPYING ${GENERATED_DOC_FILES})
    install(FILES "${FILE}" DESTINATION "${OS_AUTOINST_DOC_DIR}")
endforeach ()
foreach (FILE ${PERL_FILES} ${MISC_FILES})
    get_filename_component(SUB_DIR ${FILE} DIRECTORY)
    install(FILES "${FILE}" DESTINATION "${OS_AUTOINST_DATA_DIR}/${SUB_DIR}")
endforeach ()
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/install-target/lib/cv.pm" DESTINATION "${OS_AUTOINST_DATA_DIR}")

# install openvswitch files
install(
    FILES "os-autoinst-openvswitch"
    DESTINATION "${OS_AUTOINST_DATA_DIR}"
    PERMISSIONS ${EXECUTABLE_PERMISSIONS}
    COMPONENT "openvswitch" EXCLUDE_FROM_ALL
)
install(
    FILES "etc/dbus-1/system.d/org.opensuse.os_autoinst.switch.conf"
    DESTINATION "${CMAKE_INSTALL_FULL_SYSCONFDIR}/dbus-1/system.d"
    COMPONENT "openvswitch"
    EXCLUDE_FROM_ALL
)
add_custom_target(install-openvswitch
    COMMAND "${CMAKE_COMMAND}" -DCMAKE_INSTALL_COMPONENT=openvswitch -P "${CMAKE_BINARY_DIR}/cmake_install.cmake")

# add tests
include(test-targets)

# add target to update files containing dependency information
add_custom_target(
    update-deps
    COMMENT "Updating dependency information"
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tools/update-deps" --specfile dist/rpm/os-autoinst.spec --dockerfile docker/travis_test/Dockerfile
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
)

# add target for formatting C++ source code
find_program(CLANG_FORMAT_PATH clang-format)
add_custom_target(
    tidy-cpp
    COMMENT "Formatting C++ source code"
    COMMAND sh -c "'${CLANG_FORMAT_PATH}" "--style=WebKit" "-i" "$$(find" "." "-name" "\*.h" "-o" "-name" "\*.cc" "-o" "-name" "\*.cpp)'"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
)
