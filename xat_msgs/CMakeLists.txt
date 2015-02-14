cmake_minimum_required(VERSION 2.8)

project(xat_msgs C)

find_package(PkgConfig)
find_package(LCM REQUIRED)
find_package(Vala REQUIRED)
pkg_check_modules(gobject2 REQUIRED gobject-2.0)

include(UseVala)

lcm_add_message_files(
  FILES
  header_t.lcm
  gps_fix_t.lcm
  joint_state_t.lcm
  joint_goal_t.lcm
  voltage_t.lcm
  command_t.lcm
)

lcm_generate_messages()

#
# Generate vala library with messages
#

set(vala_msgs "")
set(vala_msgs_c "")
foreach(msg ${xat_msgs_MESSAGE_FILES})
  get_filename_component(msg_ws ${msg} NAME_WE)
  list(APPEND vala_msgs   "${CMAKE_CURRENT_BINARY_DIR}/src/${PROJECT_NAME}.${msg_ws}.vala")
  list(APPEND vala_msgs_c "${CMAKE_CURRENT_BINARY_DIR}/src/${PROJECT_NAME}.${msg_ws}.c")
endforeach()

# based on vala_precompile, original did not work if sources path is absolute
# but here used more complex rules (lcm-gen then valac then gcc)
add_custom_command(
  OUTPUT ${vala_msgs_c}
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/lcm_message.c
  COMMAND mkdir -p ${CMAKE_BINARY_DIR}/vapi
  COMMAND ${VALA_EXECUTABLE}
  ARGS
    -C
    -d ${CMAKE_CURRENT_BINARY_DIR}
    --header ${CMAKE_BINARY_DIR}/include/${PROJECT_NAME}.h
    --internal-header ${CMAKE_BINARY_DIR}/include/${PROJECT_NAME}_internal.h
    --vapi ${CMAKE_BINARY_DIR}/vapi/${PROJECT_NAME}.vapi
    --library ${PROJECT_NAME}
    --pkg lcm
    --thread
    ${LCM_MESSAGE_VALA}
    ${vala_msgs}
  DEPENDS
    ${vala_msgs}
)

include_directories(
  ${CMAKE_BINARY_DIR}/include
  ${LCM_INCLUDE_DIRS}
  ${gobject2_INCLUDE_DIRS}
)

add_library(xat_msgs SHARED
  ${CMAKE_CURRENT_BINARY_DIR}/lcm_message.c
  ${vala_msgs_c}
)
target_link_libraries(xat_msgs
  ${LCM_LIBRARIES}
  ${gobject2_LIBRARIES}
)

#
# Install
#

install(TARGETS xat_msgs
  LIBRARY DESTINATION lib
)

# vim:set ts=2 sw=2 et:
