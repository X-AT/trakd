cmake_minimum_required(VERSION 2.8)

project(xat_msgs C)

find_package(PkgConfig)
find_package(LCM REQUIRED)
find_package(Vala REQUIRED)
pkg_check_modules(libudev REQUIRED libudev)
pkg_check_modules(gobject2 REQUIRED gobject-2.0)

include(UseVala)

vala_precompile(VALA_C
  src/rotd.vala
PACKAGES
  posix
  hidapi
OPTIONS
  --thread
  --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/vapi
)

include_directories(
  ../xat_rotd/include
  ${LCM_INCLUDE_DIRS}
  ${libudev_INCLUDE_DIRS}
  ${gobject2_INCLUDE_DIRS}
)

add_library(hidapi-hidraw
  ../xat_rotd/src/hid-hidraw.c
)
target_link_libraries(hidapi-hidraw
  ${libudev_LIBRARIES}
)

add_executable(xat_rotd_vala
  ${VALA_C}
)
target_link_libraries(xat_rotd_vala
  hidapi-hidraw
  #${LCM_LIBRARIES}
  ${gobject2_LIBRARIES}
)

install(TARGETS xat_rotd_vala hidapi-hidraw
  RUNTIME DESTINATION bin
  ARCHIVE DESTINATION lib
)

# vim:set ts=2 sw=2 et:
