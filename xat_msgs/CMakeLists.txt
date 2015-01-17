cmake_minimum_required(VERSION 2.8)

project(xat_msgs NONE)

find_package(LCM REQUIRED)

add_message_files(
  FILES
  header_t.lcm
  gps_fix_t.lcm
  joint_state_t.lcm
  joint_goal_t.lcm
  voltage_t.lcm
)

generate_messages()

# vim:set ts=2 sw=2 et:
