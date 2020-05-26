local ecs = ...
local world = ecs.world

local fs = require "filesystem"
local lfs = require "filesystem.local"

local renderpkg  = import_package 'ant.render'
local math3d  = require 'math3d'

local eventInstancePrefab = world:sub {"instance_prefab"}
local eventSerializePrefab = world:sub {"serialize_prefab"}

local m = ecs.system 'init_system'

local root
local entities = {}

local function normalizeAabb()
    local aabb
    for _, eid in ipairs(entities) do
        local e = world[eid]
        if e.mesh and e.mesh.bounding then
            local newaabb = math3d.aabb_transform(e.transform.srt, e.mesh.bounding.aabb)
            aabb = aabb and math3d.aabb_merge(aabb, newaabb) or newaabb
        end
    end
    local aabb_mat = math3d.tovalue(aabb)
    local min_x, min_y, min_z = aabb_mat[1], aabb_mat[2], aabb_mat[3]
    local max_x, max_y, max_z = aabb_mat[5], aabb_mat[6], aabb_mat[7]
    local s = 1/math.max(max_x - min_x, max_y - min_y, max_z - min_z)
    local t = {-(max_x+min_x)/2,-min_y,-(max_z+min_z)/2}
    local transform = math3d.mul(math3d.matrix{ s = s }, { t = t })

    local e = world[root]
    e.transform.srt.m = math3d.mul(transform, e.transform.srt)
end

local function instancePrefab(filename)
    if root then world:remove_entity(root) end
    for _, eid in ipairs(entities) do
        world:remove_entity(eid)
    end

    root = world:create_entity {
        policy = {
            "ant.scene|transform_policy",
        },
        data = {
            transform = world.component:transform {
                srt = world.component:srt {}
            }
        }
    }
    entities = world:instance(filename, {connection={root=root}})
    normalizeAabb()
    world:pub {"editor", "prefab", entities}
end

local function write_file(filename, data)
    local f = assert(lfs.open(fs.path(filename):localpath(), "wb"))
    f:write(data)
    f:close()
end

local function serializePrefab(filename)
    local serialize = import_package "ant.serialize"
    write_file(filename, serialize.prefab(world, entities, {{mount="root"}}))
end

function m:init()
    renderpkg.components.create_grid_entity(world, "", nil, nil, nil, {srt={r = {0,0.92388,0,0.382683},}})
    world:instance '/pkg/tools.viewer.prefab_viewer/light_directional.prefab'

    if fs.exists(fs.path "/pkg/tools.viewer.prefab_viewer/res/root.prefab") then
        instancePrefab "/pkg/tools.viewer.prefab_viewer/res/root.prefab"
        return
    end
    if fs.exists(fs.path "/pkg/tools.viewer.prefab_viewer/res/root.glb") then
        instancePrefab "/pkg/tools.viewer.prefab_viewer/res/root.glb|mesh.prefab"
        return
    end
end

function m:post_init()
    local e = world:singleton_entity "main_queue"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
end

function m:data_changed()
    for _, filename in eventInstancePrefab:unpack() do
        instancePrefab(filename)
    end
    for _, filename in eventSerializePrefab:unpack() do
        serializePrefab(filename)
    end
end
