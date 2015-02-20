#!/usr/bin/env lua

local lcm = require('lcm')

-- this might be necessary depending on platform and LUA_PATH
package.path = './?/init.lua;' .. package.path

local xat_msgs = require('xat_msgs')

function handler_joint_state(channel, data)
	local msg = xat_msgs.joint_state_t.decode(data)

	local az_estop = ''
	if msg.azimuth_in_endstop then
		az_estop = 'AT ENDSTOP'
	end

	local el_estop = ''
	if msg.elevation_in_endstop then
		el_estop = 'AT ENDSTOP'
	end

	--os.execute("tput home")
	os.execute("clear")
	print(string.format("Azimuth:   %3.6f rad (%+7d) %s",
		msg.azimuth_angle, msg.azimuth_step_cnt, az_estop))
	print(string.format("Elevation: %3.6f rad (%+7d) %s",
		msg.elevation_angle, msg.elevation_step_cnt, el_estop))

	if msg.homing_in_proc then
		print("HOMING IN PROCESS")
	end
end

lc = lcm.lcm.new()
sub = lc:subscribe("xat/rot/state", handler_joint_state)

while true do
	lc:handle()
end
