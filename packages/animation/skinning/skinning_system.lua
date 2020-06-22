local ecs = ...
local world = ecs.world

local animodule = require "hierarchy.animation"
local bgfx 		= require "bgfx"

local sm = ecs.transform "skinning_material"

function sm.process_prefab(e)
	if e.skinning_type == "GPU" then
		e._cache_prefab.material_setting = {skinning = "GPU"}
	end
end

-- skinning system
local skinning_sys = ecs.system "skinning_system"

local itransform = world:interface "ant.scene|itransform"

function skinning_sys:skin_mesh()
	for _, eid in world:each "skinning" do
		local e = world[eid]
		local skinning = e.skinning
		local skin = skinning.skin
		local skinning_matrices = skinning.skinning_matrices
		local pr = e.pose_result
		if e.skinning_type == "CPU" then
			animodule.build_skinning_matrices(skinning_matrices, pr, skin.inverse_bind_pose, skin.joint_remap)

			for _, job in ipairs(skinning.jobs) do
				local handle = job.hwbuffer_handle
				local updatedata = job.updatedata
				for _, part in ipairs(job.parts) do
					animodule.mesh_skinning(skinning_matrices, part.inputdesc, part.outputdesc, part.num, part.influences_count)
				end
	
				bgfx.update(handle, 0, bgfx.memory_buffer(updatedata:pointer(), job.buffersize, updatedata))
			end
		else
			animodule.build_skinning_matrices(skinning_matrices, pr, skin.inverse_bind_pose, skin.joint_remap, itransform.worldmat(eid))
		end
	end
end
