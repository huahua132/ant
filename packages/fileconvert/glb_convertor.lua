local glTF = import_package "ant.glTF"
local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local mu = mathpkg.util

local glbloader = glTF.glb

local gltf_converter = require "meshconverter.gltf"
local filtermesh = require "filter_mesh"

local accessor_types = {
	SCALAR = 0,
	VEC2 = 1,
	VEC3 = 2,
	VEC4 = 3,
	MAT2 = 4,
	MAT3 = 5,
	MAT4 = 6,
}

local function find_accessor_type(t)
	for k, v in pairs(accessor_types) do
		if v == t then
			return k
		end
	end
end

local ENUM_ARRAY_BUFFER = 34962
local ENUM_ELEMENT_ARRAY_BUFFER = 34963


local bufferview_sizebytes = 4 + 4 + 4 + 4

local function is_4_byte_align(num)
	if num // 4 ~= num / 4 then
		error("not 4 byte align")
	end
end

is_4_byte_align(bufferview_sizebytes)

local function compile_bufferview(bv)
	return string.pack("<I4I4I4I4",
		bv.byteOffset, 
		bv.byteLength,
		bv.byteStride or 0,
		bv.target or ENUM_ARRAY_BUFFER)
end

local function compile_number_array(numberarray)
	local num = #numberarray
	for _=num+1, 16 do
		numberarray[#numberarray+1] = 0
	end
	assert(#numberarray == 16)
	return string.pack("<I4ffffffffffffffff", num, table.unpack(numberarray))
end

local accessor_sizebytes = (4 + 4 + 4 + 4 + 1 + 1 + 2) + (4 + 16 * 4) + (4 + 16 * 4)
is_4_byte_align(accessor_sizebytes)

local function compile_accessor(accessor, new_bvidx)
	return string.pack("<I4I4I4I4I1I1I2", 
		new_bvidx,
		accessor.byteOffset or 0,
		accessor.componentType,
		accessor.count,
		accessor.normalized and 1 or 0,
		accessor_types[accessor.type],
		0)	-- padding data for 4 bytes align
		.. compile_number_array(accessor.min or {})
		.. compile_number_array(accessor.max or {})
end

local attribname_mapper = {
	POSITION = 0,

	NORMAL = 1,
	TANGENT = 2,
	BITANGENT = 3,

	COLOR_0 = 4,
	COLOR_1 = 5,
	COLOR_2 = 6,
	COLOR_3 = 7,

	TEXCOORD_0 = 8,
	TEXCOORD_1 = 9,
	TEXCOORD_2 = 10,
	TEXCOORD_3 = 11,
	TEXCOORD_4 = 12,
	TEXCOORD_5 = 13,
	TEXCOORD_6 = 14,
	TEXCOORD_7 = 15,

	WEIGHTS_0 = 16,
	WEIGHTS_1 = 17,

	JOINTS_0 = 18,
	JOINTS_1 = 19,

}

local function compile_primitive(scene, primitive)
	local attributes = primitive.attributes

	local accessors = scene.accessors
	local bufferViews = scene.bufferViews

	local seri_attrib = {}
	local seri_accessor = {}
	local seri_bufferview = {}

	local function serialize_accessor(accessor)
		local new_bvidx = #seri_bufferview+1
		seri_accessor[#seri_accessor+1] = compile_accessor(accessor, new_bvidx-1)
		seri_bufferview[new_bvidx] = compile_bufferview(bufferViews[accessor.bufferView + 1])
	end

	local sort_attributes = {}
	for name in pairs(attributes) do
		sort_attributes[#sort_attributes+1] = name
	end
	table.sort(sort_attributes, function (lhs, rhs) return attribname_mapper[lhs] < attribname_mapper[rhs] end)

	for _, name in ipairs(sort_attributes) do
		local accidx = attributes[name]
		local accessor = accessors[accidx+1]
		local attribidx = attribname_mapper[name]
		seri_attrib[#seri_attrib+1] = string.pack("<I4I4", attribidx, #seri_accessor)

		serialize_accessor(accessor)
	end

	if primitive.indices then
		local indices_acc = accessors[primitive.indices + 1]
		primitive.indices = #seri_accessor
		serialize_accessor(indices_acc)
	end

	local function concat_table(t)
		return string.pack("<I4", #t) .. table.concat(t, "")
	end

	return concat_table(seri_attrib) .. 
			string.pack("<I4", primitive.indices or 0xffffffff) .. 
			string.pack("<I4", primitive.material or 0xffffffff) .. 
			string.pack("<I4", primitive.mode or 4) .. 
			concat_table(seri_accessor) .. 
			concat_table(seri_bufferview)
end

local function find_attrib_name(attribname_idx)
	for k, v in pairs(attribname_mapper)do
		if v == attribname_idx then
			return k
		end
	end
end

local function deserialize_bufferview(seri_data, seri_offset)
	local bv = {}
	bv.byteOffset, bv.byteLength, bv.byteStride, bv.target = 
	string.unpack("<I4I4I4I4", seri_data, seri_offset)	
	if bv.byteStride == 0 then
		bv.byteStride = nil
	end

	seri_offset = seri_offset + 4 + 4 + 4 + 4
	return bv, seri_offset
end

local function deserialize_accessor(seri_data, seri_offset)
	local acc = {}
	acc.bufferView, acc.byteOffset,	acc.componentType,	acc.count, 
	acc.normalized,	acc.type = 
	string.unpack("<I4I4I4I4I1I1", seri_data, seri_offset)
	
	seri_offset = seri_offset + 4 + 4 + 4 + 4 + 1 + 1 + 2	-- 2 for padding

	acc.normalized = acc.normalized ~= 0
	acc.type = find_accessor_type(acc.type)

	local function unpack_array(seri_data, seri_offset)
		local num = string.unpack("<I4", seri_data, seri_offset)
		if num ~= 0 then
			seri_offset = seri_offset + 4

			local value = table.pack(string.unpack("<ffffffffffffffff", seri_data, seri_offset))		
			local t = {}
			table.move(value, 1, num, 1, t)
			return t
		end
	end

	acc.min = unpack_array(seri_data, seri_offset)
	seri_offset = seri_offset + 4 + 16 * 4
	acc.max = unpack_array(seri_data, seri_offset)
	seri_offset = seri_offset + 4 + 16 * 4
	return acc, seri_offset
end

local function deserialize_primitive_itself(seri_data, seri_offset)
	local numattrib = string.unpack("<I4", seri_data, seri_offset)
	seri_offset = seri_offset + 4

	local prim = {}

	local attributes = {}
	for _=1, numattrib do
		local attribidx, accidx = string.unpack("<I4I4", seri_data, seri_offset)
		local name = find_attrib_name(attribidx)
		attributes[name] = accidx
		seri_offset = seri_offset + 4 + 4
	end

	prim.attributes = attributes

	local index_buffer_idx = string.unpack("<I4", seri_data, seri_offset)
	seri_offset = seri_offset + 4
	prim.indices = index_buffer_idx ~= 0xffffffff and index_buffer_idx or nil

	local material_idx = string.unpack("<I4", seri_data, seri_offset)
	seri_offset = seri_offset + 4
	prim.material = material_idx ~= 0xffffffff and material_idx or nil

	prim.mode = string.unpack("<I4", seri_data, seri_offset)
	seri_offset = seri_offset + 4
	return prim, seri_offset
end

local function deserialize_primitive(seri_data)	
	local prim, seri_offset = deserialize_primitive_itself(seri_data, 1)

	local accessors = {}	
	local num_accessor = string.unpack("<I4", seri_data, seri_offset)
	seri_offset = seri_offset + 4
	for ii=1, num_accessor do
		accessors[ii], seri_offset = deserialize_accessor(seri_data, seri_offset)
	end

	local bufferviews = {}	
	local num_bufferview = string.unpack("<I4", seri_data, seri_offset)
	seri_offset = seri_offset + 4
	for ii=1, num_bufferview do
		bufferviews[ii], seri_offset = deserialize_bufferview(seri_data, seri_offset)
		bufferviews[ii].buffer = 0
	end

	return prim, accessors, bufferviews
end

local function reset_root_pos(scene)
	local nodes = scene.nodes
	local scenerootnodes = scene.scenes[scene.scene+1].nodes
	for _, nodeidx in ipairs(scenerootnodes) do
		local node = nodes[nodeidx+1]
		local matrix = node.matrix
		if matrix then
			matrix[15], matrix[14], matrix[13] = 0, 0, 0
		end

		local tran = node.translation
		if tran then
			tran[1], tran[2], tran[3] = 0, 0, 0
		end
	end
end

local function refine_prim_offset(newprim, newacc, newbvs, newscene)
	local accessor_index_offset = #newscene.accessors
	local bufferview_index_offset = #newscene.bufferViews

	if bufferview_index_offset ~= 0 then
		for _, acc in ipairs(newacc) do
			acc.bufferView = acc.bufferView + bufferview_index_offset
		end
	end

	if accessor_index_offset ~= 0 then
		local newattributes = newprim.attributes
		for k, v in pairs(newattributes) do
			newattributes[k] = v + accessor_index_offset
		end

		if newprim.indices then
			newprim.indices = newprim.indices + accessor_index_offset
		end
	end

	local bindata_offset = newscene.buffers[1].byteLength
	if bindata_offset ~= 0 then
		for _, bv in ipairs(newbvs) do
			bv.byteOffset = bv.byteOffset + bindata_offset
		end
	end

	table.move(newacc, 1, #newacc, #newscene.accessors+1, newscene.accessors)
	table.move(newbvs, 1, #newbvs, #newscene.bufferViews+1, newscene.bufferViews)
end

local function get_scale(cfg)
	local m = cfg.mesh
	if m then
		return m.scale or 1
	end
	return 1
end

local function get_convert_matrix(negative_axis)
	local reverse_matrix = {
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1,
	}
	local indices = {
		X = 1, Y = 6, Z = 11,
	}
	reverse_matrix[indices[negative_axis]] = -1
	return reverse_matrix
end

local function convert_coord_system(scene, meshcfg)
	if meshcfg.coord_system == "right" then
		local scenelods = scene.scenelods or {scene.scene}
		for _, sceneidx in ipairs(scenelods)do
			local rootnodes = scene.scenes[sceneidx+1].nodes
			for _, nodeidx in ipairs(rootnodes)do
				local node = scene.nodes[nodeidx+1]
				if node.matrix then
					-- local function split_matrix(m)
					-- 	local m3x3 = {}
					-- 	for idx, v in ipairs(m) do
					-- 		m3x3[idx] = v
					-- 	end

					-- 	for _, idx in ipairs {4, 8, 12, 13, 14, 15} do
					-- 		m3x3[idx] = 0
					-- 	end
					-- 	m3x3[16] = 1

					-- 	return m3x3, {m[13], m[14], m[15], 1}
					-- end

					-- local rot, translate = split_matrix(node.matrix)
					-- local m = ms(convert_matrix, rot, convert_matrix, "**T")
					-- m.type = nil
					-- local t = ms(convert_matrix, translate, "*T")
					-- m[13], m[14], m[15] = t[1], t[2], t[3]
					local indices = {X=1, Y=6, Z=11}
					local index = indices[meshcfg.negative_axis]
					node.matrix[index] = -node.matrix[index]
				else
					assert(node.scale and node.rotation and node.translation)
					local indices = {X=1, Y=2, Z=3}
					local index = indices[meshcfg.negative_axis]
					node.scale[index] = -node.scale[index]
				end
			end
		end
	end
end

return function (srcname, dstname, cfg)
	local glbdata = glbloader.decode(srcname)
	local scene = glbdata.info
	local scenes, nodes, meshes = scene.scenes, scene.nodes, scene.meshes

	local scenerootnode = scenes[scene.scene+1].nodes

	local new_bindata_table = {}
	local newscene = {
		scene = scene.scene,
		scenes = scenes,
		scenelods = scene.scenelods,
		scenescale = get_scale(cfg),
		nodes = nodes,
		meshes = meshes,
		accessors = {},
		bufferViews = {},
		buffers = {
			{byteLength = 0,}
		},
		asset = {
			version = scene.asset.version,
			generator = "ant(" .. scene.asset.generator .. ")",
		}
	}

	local function fetch_mesh_buffers(scenenodes)
		for _, nodeidx in ipairs(scenenodes) do
			local node = nodes[nodeidx + 1]
			if node.children then
				fetch_mesh_buffers(node.children)
			end
			
			if node.mesh then
				local meshidx = node.mesh + 1
				local mesh = meshes[meshidx]
				local primitives = mesh.primitives
				for idx, prim in ipairs(primitives) do
					local seri_prim = compile_primitive(scene, prim)
					local new_seri_prim, prim_binary_buffers = gltf_converter.convert_buffers(seri_prim, glbdata.bin, cfg)
					local newprim, newacc, newbvs = deserialize_primitive(new_seri_prim)
					
					refine_prim_offset(newprim, newacc, newbvs, newscene)

					primitives[idx] = newprim

					new_bindata_table[#new_bindata_table+1] = prim_binary_buffers
					newscene.buffers[1].byteLength = newscene.buffers[1].byteLength + #prim_binary_buffers
				end
			end
		end
	end

	fetch_mesh_buffers(scenerootnode)
	
	local new_bindata = table.concat(new_bindata_table, "")

	if cfg.flags.reset_root_pos then
		reset_root_pos(newscene)
	end

	if cfg.lod then
		filtermesh.spiltlod(newscene, cfg.lod)
	end

	if cfg.flags.extract_colider_mesh then
		filtermesh.extract_colider_mesh(newscene)
	end

	local meshcfg = cfg.mesh
	if meshcfg then
		convert_coord_system(newscene, meshcfg)
	end

	glbloader.encode(dstname, {version=glbdata.version, info=newscene, bin=new_bindata})
end