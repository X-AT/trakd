cmake_minimum_required(VERSION 2.8)

project(xat_rotd C)

find_package(PkgConfig)
find_package(LCM REQUIRED)
find_package(Vala REQUIRED)
pkg_check_modules(libudev REQUIRED libudev)
pkg_check_modules(gobject2 REQUIRED gobject-2.0)

include(UseVala)

vala_precompile(VALA_C
  src/rotd.vala
  src/hid_conn.vala
PACKAGES
  hidapi
  lcm
  xat_msgs
OPTIONS
  --thread
  --vapidir=${CMAKE_SOURCE_DIR}/hidapi/vapi
  --vapidir=${CMAKE_BINARY_DIR}/vapi
)

include_directories(
  ${CMAKE_BINARY_DIR}/include
  ${CMAKE_SOURCE_DIR}/hidapi/include
  ${LCM_INCLUDE_DIRS}
  ${libudev_INCLUDE_DIRS}
  ${gobject2_INCLUDE_DIRS}
)

add_executable(xat_rotd_vala
  ${VALA_C}
)
target_link_libraries(xat_rotd_vala
  xat_msgs
  hidapi-hidraw
  ${LCM_LIBRARIES}
  ${gobject2_LIBRARIES}
)

install(TARGETS xat_rotd_vala
  RUNTIME DESTINATION bin
)

# vim:set ts=2 sw=2 et:
