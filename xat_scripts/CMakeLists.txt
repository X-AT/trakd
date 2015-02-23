cmake_minimum_required(VERSION 2.8)

project(xat_scripts NONE)

find_package(LCM REQUIRED)

file(GLOB SCRIPTS ${PROJECT_SOURCE_DIR}/scripts/*.lua)

#install(FILES ${SCRIPTS} DESTINATION bin)

# vim:set ts=2 sw=2 et:
