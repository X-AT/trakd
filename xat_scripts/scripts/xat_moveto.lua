#!/usr/bin/env lua

local lcm = require('lcm')

-- this might be necessary depending on platform and LUA_PATH
package.path = './?/init.lua;' .. package.path

local xat_msgs = require('xat_msgs')

local lc = lcm.lcm.new()

local msg = xat_msgs.joint_goal_t:new()

-- XXX: find how to produce right header (seq+stamp)
msg.header = xat_msgs.header_t:new()
msg.azimuth_angle = arg[1]
msg.elevation_angle = arg[2]

lc:publish("xat/rot_goal", msg:encode())
print "Goal published."
