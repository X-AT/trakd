cmake_minimum_required(VERSION 2.8)

project(hidapi C)

find_package(PkgConfig)
pkg_check_modules(libudev REQUIRED libudev)

include_directories(
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${libudev_INCLUDE_DIRS}
)

add_library(hidapi-hidraw STATIC
  src/hid-hidraw.c
)
target_link_libraries(hidapi-hidraw
  ${libudev_LIBRARIES}
)

#installation not needed
#install(TARGETS hidapi-hidraw
#  ARCHIVE DESTINATION lib
#)
#inctall(FILES include/hidapi/hidapi.h
#  DESTINATION include/${PROJECT_NAME}
#)
#install(FILES vapi/hidapi.vapi
#  DATA DESTINATION vala/vapi
#)

# vim:set ts=2 sw=2 et:
