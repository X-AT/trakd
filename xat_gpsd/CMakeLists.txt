cmake_minimum_required(VERSION 2.8)

project(xat_gpsd C)

find_package(PkgConfig)
find_package(LCM REQUIRED)
find_package(Vala REQUIRED)
pkg_check_modules(libgps REQUIRED libgps)
pkg_check_modules(gobject2 REQUIRED gobject-2.0)

include(UseVala)

vala_precompile(VALA_C
  src/gpsd.vala
PACKAGES
  libgps
  lcm
  xat_msgs
OPTIONS
  --thread
  --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/vapi
  --vapidir=${CMAKE_BINARY_DIR}/vapi
)

include_directories(
  ${CMAKE_BINARY_DIR}/include
  ${LCM_INCLUDE_DIRS}
  ${gobject2_INCLUDE_DIRS}
  ${libgps_INCLUDE_DIRS}
)

add_executable(xat-gpsd
  ${VALA_C}
)
target_link_libraries(xat-gpsd
  xat_msgs
  ${LCM_LIBRARIES}
  ${gobject2_LIBRARIES}
  ${libgps_LIBRARIES}
)

install(TARGETS xat-gpsd
  RUNTIME DESTINATION bin
)

# vim:set ts=2 sw=2 et:
