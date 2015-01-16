cmake_minimum_required(VERSION 2.8)

project(xat_msgs CXX)

find_package(PkgConfig)
find_package(LCM REQUIRED)
find_package(Boost REQUIRED COMPONENTS system program_options)
find_package(console_bridge REQUIRED)
pkg_check_modules(libudev REQUIRED libudev)

include(EnableCXX11)

include_directories(
  include
  ${CMAKE_BINARY_DIR}/include
  ${Boost_INCLUDE_DIRS}
  ${console_bridge_INCLUDE_DIRS}
  ${LCM_INCLUDE_DIRS}
  ${libudev_INCLUDE_DIRS}
)

add_executable(xat_rotd
  src/xat_rotd.cpp
  src/hid-hidraw.c
)
target_link_libraries(xat_rotd
  ${Boost_LIBRARIES}
  ${console_bridge_LIBRARIES}
  ${LCM_LIBRARIES}
  ${libudev_LIBRARIES}
)

install(TARGETS xat_rotd
  RUNTIME DESTINATION bin
)

# vim:set ts=2 sw=2 et:
