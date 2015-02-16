cmake_minimum_required(VERSION 2.8)

project(xat_mavlinkd C)

find_package(PkgConfig)
find_package(LCM REQUIRED)
find_package(Vala REQUIRED)
pkg_check_modules(libgps REQUIRED libgps)
pkg_check_modules(gobject2 REQUIRED gobject-2.0)
pkg_check_modules(gio REQUIRED gio-2.0)

include(UseVala)

vala_precompile(VALA_C
  src/mavlinkd.vala
PACKAGES
  gio-2.0
  mavlink
  lcm
  xat_msgs
OPTIONS
  --thread
  --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/vapi
  --vapidir=${CMAKE_BINARY_DIR}/vapi
)

find_path(MAVLINK_INCLUDE_DIR
  NAMES "mavlink/v1.0/common/mavlink.h"
  PATHS
    "/usr/include"
    "/usr/local/include"
)
message(STATUS "Mavlink headers: ${MAVLINK_INCLUDE_DIR}")

include_directories(
  ${CMAKE_BINARY_DIR}/include
  ${LCM_INCLUDE_DIRS}
  ${gobject2_INCLUDE_DIRS}
  ${gio_INCLUDE_DIRS}
  ${MAVLINK_INCLUDE_DIR}
)

add_executable(xat_mavlinkd
  ${VALA_C}
)
target_link_libraries(xat_mavlinkd
  xat_msgs
  ${LCM_LIBRARIES}
  ${gobject2_LIBRARIES}
  ${gio_LIBRARIES}
)

install(TARGETS xat_mavlinkd
  RUNTIME DESTINATION bin
)

# vim:set ts=2 sw=2 et:
