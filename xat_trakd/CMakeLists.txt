cmake_minimum_required(VERSION 2.8)

project(xat_trakd C)

find_package(PkgConfig)
find_package(LCM REQUIRED)
find_package(Vala REQUIRED)
pkg_check_modules(gobject2 REQUIRED gobject-2.0)
pkg_check_modules(gio REQUIRED gio-2.0)

include(UseVala)

vala_precompile(VALA_C
  src/trakd.vala
  src/geo.vala
PACKAGES
  gio-2.0
  lcm
  xat_msgs
OPTIONS
  --thread
  --vapidir=${CMAKE_BINARY_DIR}/vapi
)

include_directories(
  ${CMAKE_BINARY_DIR}/include
  ${LCM_INCLUDE_DIRS}
  ${gobject2_INCLUDE_DIRS}
  ${gio_INCLUDE_DIRS}
)

add_executable(xat-trakd
  ${VALA_C}
)
target_link_libraries(xat-trakd
  m
  xat_msgs
  ${LCM_LIBRARIES}
  ${gobject2_LIBRARIES}
  ${gio_LIBRARIES}
)

install(TARGETS xat-trakd
  RUNTIME DESTINATION bin
)

# vim:set ts=2 sw=2 et:
