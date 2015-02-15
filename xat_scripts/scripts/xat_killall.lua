#!/usr/bin/env lua

local lcm = require('lcm')

-- this might be necessary depending on platform and LUA_PATH
package.path = './?/init.lua;' .. package.path

local xat_msgs = require('xat_msgs')

local lc = lcm.lcm.new()

local msg = xat_msgs.command_t:new()

-- XXX: find how to produce right header (seq+stamp)
msg.header = xat_msgs.header_t:new()
msg.command = 800

lc:publish("xat/command", msg:encode())
print "Terminate command published."
