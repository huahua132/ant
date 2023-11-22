local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local m = ecs.system "entity_system"

local evOnMessage = world:sub {"EntityMessage"}
local evOnRemoveInstance = world:sub {"OnRemoveInstance"}

local PipelineEntityRemove

function m:entity_ready()
    for v in w:select "on_ready:in" do
        v:on_ready()
    end
    w:clear "on_ready"
end

function m:data_changed()
    for msg in evOnMessage:each() do
        local eid = msg[2]
        local v = w:fetch(eid, "on_message:in")
        if v then
            v:on_message(table.unpack(msg, 3))
            w:submit(v)
        end
    end
end

function m:frame_finish()
    --step1. Remove prefab
    for _, instance in evOnRemoveInstance:unpack() do
        instance.REMOVED = true
        if instance.proxy then
            w:remove(instance.proxy)
        end
        for _, entity in ipairs(instance.tag["*"]) do
            w:remove(entity)
        end
    end

    --step2. Destroy entity
    if w:check "REMOVED" then
        PipelineEntityRemove()
        for name, func in pairs(world._component_remove) do
            for v in w:select("REMOVED "..name..":in") do
                func(v[name])
            end
        end
    end
    local destruct = world._destruct
    if #destruct > 0 then
        world._destruct = {}
        for _, f in ipairs(destruct) do
            f(world)
        end
    end

    --step3. Remove entity
    w:update()

    --step4. Create entity
    world:_flush_instance_queue()
    world:_flush_entity_queue()

    --step5. reset math3d
    math3d.reset()
end

function m:pipeline()
    PipelineEntityRemove = world:pipeline_func "_entity_remove"
end
