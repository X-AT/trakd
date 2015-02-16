# This module finds LCM library and lcm-gen executable.

find_package(PkgConfig)
pkg_check_modules(LCM REQUIRED lcm)

find_program(LCM_GEN NAMES lcm-gen)
mark_as_advanced(LCM_GEN)

if(LCM_GEN)
  execute_process(COMMAND ${LCM_GEN} "--version"
    OUTPUT_VARIABLE LCM_GEN_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  message(STATUS "LCM gen: ${LCM_GEN} : ${LCM_GEN_VERSION}")
endif()

find_path(LCM_MESSAGE_VALA_PATH NAMES "lcm_message.vala" PATHS "/usr/src/lcm" "/usr/local/src/lcm")
message(STATUS "LCM Vala message: ${LCM_MESSAGE_VALA_PATH}")
set(LCM_MESSAGE_VALA "${LCM_MESSAGE_VALA_PATH}/lcm_message.vala")
mark_as_advanced(LCM_MESSAGE_VALA_PATH LCM_MESSAGE_VALA)

# based on ROS genmsg-extras.cmake

include(CMakeParseArguments)
include(assert)

macro(_prepend_path ARG_PATH ARG_FILES ARG_OUTPUT_VAR)
  cmake_parse_arguments(ARG "UNIQUE" "" "" ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "_prepend_path() called with unused arguments: ${ARG_UNPARSED_ARGUMENTS}")
  endif()
  # todo, check for proper path, slasheds, etc
  set(${ARG_OUTPUT_VAR} "")
  foreach(_file ${ARG_FILES})
    set(_value ${ARG_PATH}/${_file})
    list(FIND ${ARG_OUTPUT_VAR} ${_value} _index)
    if(NOT ARG_UNIQUE OR _index EQUAL -1)
      list(APPEND ${ARG_OUTPUT_VAR} ${_value})
    endif()
  endforeach()
endmacro()

macro(lcm_add_message_files)
  cmake_parse_arguments(ARG "" "DIRECTORY" "FILES" ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "lcm_add_message_files() called with unused arguments: ${ARG_UNPARSED_ARGUMENTS}")
  endif()

  if(NOT ARG_DIRECTORY)
    set(ARG_DIRECTORY "msg")
  endif()

  set(MESSAGE_DIR "${ARG_DIRECTORY}")
  if(NOT IS_ABSOLUTE "${MESSAGE_DIR}")
    set(MESSAGE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/${MESSAGE_DIR}")
  endif()

  if(NOT IS_DIRECTORY ${MESSAGE_DIR})
    message(FATAL_ERROR "lcm_add_message_files() directory not found: ${MESSAGE_DIR}")
  endif()

  if(${PROJECT_NAME}_GENERATE_MESSAGES)
    message(FATAL_ERROR "lcm_generate_messages() must be called after lcm_add_message_files()")
  endif()

  # if FILES are not passed search message files in the given directory
  # note: ARGV is not variable, so it can not be passed to list(FIND) directly
  set(_argv ${ARGV})
  list(FIND _argv "FILES" _index)
  if(_index EQUAL -1)
    file(GLOB ARG_FILES RELATIVE "${MESSAGE_DIR}" "${MESSAGE_DIR}/*.lcm")
    list(SORT ARG_FILES)
  endif()
  _prepend_path(${MESSAGE_DIR} "${ARG_FILES}" FILES_W_PATH)

  list(APPEND ${PROJECT_NAME}_MESSAGE_FILES ${FILES_W_PATH})
  foreach(file ${FILES_W_PATH})
    assert_file_exists(${file} "message file not found")
  endforeach()
endmacro()

macro(lcm_generate_messages)
  if(${PROJECT_NAME}_GENERATE_MESSAGES)
    message(FATAL_ERROR "lcm_generate_messages() must only be called once per project'")
  endif()

  set(ARG_MESSAGES ${${PROJECT_NAME}_MESSAGE_FILES})

  # mark that generate_messages() was called in order to detect wrong order of calling with catkin_python_setup()
  set(${PROJECT_NAME}_GENERATE_MESSAGES TRUE)

  foreach(msg ${ARG_MESSAGES})
    get_filename_component(msg_ws ${msg} NAME_WE)
    message(STATUS "processing: ${msg} ${target}")
    add_custom_command(
      OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/lua/${PROJECT_NAME}/${msg_ws}.lua
      OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/src/${PROJECT_NAME}.${msg_ws}.vala
      COMMAND mkdir -p ${CMAKE_CURRENT_BINARY_DIR}/lua
      COMMAND ${LCM_GEN} --lpath ${CMAKE_CURRENT_BINARY_DIR}/lua --lua ${msg}
      COMMAND mkdir -p ${CMAKE_CURRENT_BINARY_DIR}/src
      COMMAND ${LCM_GEN} --vala-path ${CMAKE_CURRENT_BINARY_DIR}/src --vala ${msg}
      DEPENDS ${msg}
      )
    add_custom_target(lcm-gen-${PROJECT_NAME}-${msg_ws} ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/src/${PROJECT_NAME}.${msg_ws}.vala)
  endforeach()
endmacro()

# vim:set ts=2 sw=2 et:
