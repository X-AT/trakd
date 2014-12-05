cmake_minimum_required(VERSION 2.8)

project(xat_msgs CXX)

find_package(LCM REQUIRED)
find_package(Boost REQUIRED COMPONENTS system)

include(EnableCXX11)

include_directories(
  include
  ${CMAKE_BINARY_DIR}/include
  ${Boost_INCLUDE_DIRS}
  ${LCM_INCLUDE_DIRS}
)

add_executable(xat_gpsd
  src/xat_gpsd.cpp
)
target_link_libraries(xat_gpsd
  ${Boost_LIBRARIES}
  ${LCM_LIBRARIES}
)

# vim:set ts=2 sw=2 et:
