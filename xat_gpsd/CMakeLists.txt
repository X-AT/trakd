cmake_minimum_required(VERSION 2.8)

project(xat_msgs CXX)

find_package(PkgConfig)
find_package(LCM REQUIRED)
find_package(Boost REQUIRED COMPONENTS system program_options)
find_package(console_bridge REQUIRED)
pkg_check_modules(libgps REQUIRED libgps)

include(EnableCXX11)

include_directories(
  ${CMAKE_SOURCE_DIR}/include
  ${CMAKE_BINARY_DIR}/include
  ${Boost_INCLUDE_DIRS}
  ${console_bridge_INCLUDE_DIRS}
  ${LCM_INCLUDE_DIRS}
  ${libgps_INCLUDE_DIRS}
)

add_executable(xat_gpsd
  src/xat_gpsd.cpp
)
target_link_libraries(xat_gpsd
  ${Boost_LIBRARIES}
  ${console_bridge_LIBRARIES}
  ${LCM_LIBRARIES}
  ${libgps_LIBRARIES}
)

install(TARGETS xat_gpsd
  RUNTIME DESTINATION bin
)

# vim:set ts=2 sw=2 et:
