cmake_minimum_required(VERSION 2.8)

list(INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

add_subdirectory(hidapi)
add_subdirectory(xat_msgs)
add_subdirectory(xat_gpsd)
add_subdirectory(xat_rotd)
add_subdirectory(xat_scripts)

# vim:set ts=2 sw=2 et:
