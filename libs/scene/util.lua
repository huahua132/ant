local ecs = require "ecs"
local task = require "editor.task"
local asset = require "asset"

--local elog = require "editor.log"
--local db = require "debugger"

--windows dir
asset.insert_searchdir(1, "D:/Engine/ant/assets")
--mac dir
asset.insert_searchdir(2, "/Users/ejoy/Desktop/Engine/ant/assets")


local util = {}
util.__index = util

local world = nil

function util.start_new_world(input_queue, fbw, fbh, module_files)
	local modules = {}
	for _, mfile in ipairs(module_files) do
		local m = asset.load(mfile)
		table.move(m, 1, #m, #modules + 1, modules)
	end	
	world = ecs.new_world {
		modules = modules,
		update_bydepend = true,
		args = { mq = input_queue, fb_size={w=fbw, h=fbh} },
    }
    
	task.loop(world.update)  
    return world
end

return util
