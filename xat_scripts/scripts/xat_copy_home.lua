#!/usr/bin/env lua

local lcm = require('lcm')

-- this might be necessary depending on platform and LUA_PATH
package.path = './?/init.lua;' .. package.path

local xat_msgs = require('xat_msgs')

lc = lcm.lcm.new()

function handler_fix(channel, data)
	local msg = xat_msgs.gps_fix_t.decode(data)

	print(string.format("HOME FIX: %3.6f lat %3.6f long %3.2f alt",
		msg.p.latitude, msg.p.longitude, msg.p.altitude))

	lc:publish("xat/home/fix", data)
end

sub = lc:subscribe("xat/mav/fix", handler_fix)
lc:handle()
