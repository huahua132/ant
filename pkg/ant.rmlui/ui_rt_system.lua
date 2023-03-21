local ecs = ...
local world = ecs.world
local w = world.w
local ui_rt_sys = ecs.system "ui_rt_system"
local ivs		= ecs.import.interface "ant.scene|ivisible_state"
local math3d = require "math3d"
local ltask     = require "ltask"
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler
local mc 		= import_package "ant.math".constant
local iom           = ecs.import.interface "ant.objcontroller|iobj_motion"
local iUiRt = ecs.interface "iuirt"
local ui_rt_group_id = 110000

local rt2g_table = {}
local g2rt_table = {}
local focused_rt_table = {}

local rb_flags = sampler{
    MIN="POINT",
    MAG="POINT",
    U="CLAMP",
    V="CLAMP",
    RT="RT_ON",
}

local function gen_group_id(name)
    if not rt2g_table[name] then
        local queuename = name.."_queue"
        local gid = ui_rt_group_id + 1
        ui_rt_group_id = gid
        rt2g_table[name] = gid
        g2rt_table[gid]  = name
        w:register{ name = name.."_obj"}
        w:register{ name = queuename}
        w:register{ name = queuename.."_cull"}
        w:register{ name = queuename.."_visible"} 
    end
end


local S = ltask.dispatch()

--local lastname = "blit_shadowmap"

function S.render_target_create(width, height, name)
    local viewid = viewidmgr.generate(name)
    local fbidx = fbmgr.create(
        {rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "RGBA8", flags = rb_flags}},
        {rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "D16", flags = rb_flags}} 
    )
    
    local id = fbmgr.get_rb(fbidx, 1).handle
    local queuename = name .. "_queue"
    gen_group_id(name)
    ecs.create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|watch_screen_buffer",
			"ant.general|name",
		},
		data = {
            camera_ref = ecs.create_entity{
                policy = {
                    "ant.general|name",
                    "ant.camera|camera"
                },
                data = {
                    scene = {
                        r = {1, 0, 0},
                        t = {0, 8, -5, 0},
                        updir = {0.0, 1.0, 0.0}
                },
                  camera = {
                    frustum = {
                        aspect = 1.3333333333333333,
                        f = 100,
                        fov = 60,
                        n = 1,
                    }
                  },
                  exposure = {
                    type          = "manual",
                    aperture      = 16.0,
                    shutter_speed = 0.008,
                    ISO           = 20
                  },
                  name = name .. "_camera",
                }
            },
			render_target = {
				viewid		= viewid,
				view_mode 	= "s",
                clear_state = {
                    color = 0x000000ff,
                    depth = 0.0,
                    clear = "CD",
                },
				view_rect	= {x = 0, y = 0, w = width, h = height},
				fb_idx		= fbidx,
			},
            [queuename]         = true,
			name 				= queuename,
			queue_name			= queuename,
            visible = true,
			watch_screen_buffer	= true,
		}
	}
    lastname = name
    return id
end

local function calc_camera_t(queuename, aabb)
    local select_condition = queuename .. " camera_ref:in"
    local rtq = w:first(select_condition)
    if rtq then
        local rt_camera<close> = w:entity(rtq.camera_ref, "scene:update")
        local aabb_min, aabb_max = math3d.array_index(aabb, 1), math3d.array_index(aabb, 2)
        local triple_offset = 3 * math3d.length(math3d.sub(aabb_max, aabb_min))
        local unit_dir = math3d.normalize(rt_camera.scene.t)
       iom.set_position(rt_camera, math3d.mul(unit_dir, triple_offset)) 
    end
end

function iUiRt.get_group_id(name)
    return rt2g_table[name]
end

function iUiRt.create_new_rt(rt_name, focus_path, plane_path_type, light_path, scale, rotation, translation)
    focused_rt_table[rt_name] = true
    local queue_name = rt_name .. "_queue"
    local gid = iUiRt.get_group_id(rt_name)
    local g = ecs.group(gid)

    g:enable "view_visible"
    g:enable "scene_update"

    local light = g:create_instance(light_path)
    light.on_ready = function (inst)
        local alleid = inst.tag['*']
        for _, eid in ipairs(alleid) do
            local ee <close> = w:entity(eid, "visible_state?in")
            if ee.visible_state then
                ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                ivs.set_state(ee, queue_name, true)
            end
        end
    end
    world:create_object(light)  

--[[     local ground = g:create_instance(plane_path)
    ground.on_ready = function (inst)
        local alleid = inst.tag['*']
        local re <close> = w:entity(alleid[1])
        iom.set_scale(re, math3d.vector(100, 1, 100))
        for _, eid in ipairs(alleid) do
            local ee <close> = w:entity(eid, "visible_state?in name:in")
            if ee.visible_state then
                ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                ivs.set_state(ee, queue_name, true)
            end
        end
    end
    world:create_object(ground)   ]]
    if plane_path_type == "vaststars" then
        g:create_entity {
            policy = {
                "ant.general|name",
                "ant.render|render",
            },
            data = {
                mesh = "/pkg/vaststars.resources/glb/plane_rt.glb|meshes/Plane_P1.meshbin",
                material = "/pkg/vaststars.resources/materials/plane_rt.material",
                visible_state= "main_view",
                scene = {},
                name = "Plane",
                on_ready = function (e)
                    ivs.set_state(e, "main_view|selectable|cast_shadow", false)
                    ivs.set_state(e, queue_name, true)
                    iom.set_scale(e, math3d.vector(100, 1, 100))
                end
            }
        }
    elseif plane_path_type == "ant" then
        g:create_entity {
            policy = {
                "ant.general|name",
                "ant.render|render",
            },
            data = {
                mesh = "/pkg/ant.resources/glb/plane_rt.glb|meshes/Plane_P1.meshbin",
                material = "/pkg/ant.resources/materials/plane_rt.material",
                visible_state= "main_view",
                scene = {},
                name = "Plane",
                on_ready = function (e)
                    ivs.set_state(e, "main_view|selectable|cast_shadow", false)
                    ivs.set_state(e, queue_name, true)
                    iom.set_scale(e, math3d.vector(100, 1, 100))
                end
            }
        } 
    end

    local focus_entity = g:create_instance(focus_path)
    focus_entity.on_ready = function (inst)
        local alleid = inst.tag['*']
        local re <close> = w:entity(alleid[1])
        if scale then
            iom.set_scale(re, math3d.vector(scale))
        end
        if rotation then
            iom.set_direction(re, math3d.vector(rotation))
        end
        if translation then
            iom.set_position(re, math3d.vector(translation))
        end

        for _, eid in ipairs(alleid) do
            local ee <close> = w:entity(eid, "visible_state?in")
            if ee.visible_state then
                ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                ivs.set_state(ee, queue_name, true)
            end
        end 
    end       
    world:create_object(focus_entity)        
end

function iUiRt.adjust_camera(rt_name)
    if iUiRt.get_group_id(rt_name) then
        local gid = iUiRt.get_group_id(rt_name)
        local g = ecs.group(gid)
        local queue_name = rt_name .. "_queue"
        --local enable_tag = "main_queue_visible"
        local enable_tag = rt_name .. "_queue_visible"
        local select_tag = enable_tag .. " bounding:in scene:in eid:in name?in visible_state?update"
        g:enable(enable_tag)
        for ee in w:select(select_tag) do
            if not ee then
                goto continue
            end
            if ee.name and ee.name == "Plane" or ee.name == "skybox_rt" then
                goto continue
            end 
            if ee.bounding.scene_aabb and ee.bounding.scene_aabb ~= mc.NULL and ee.name then
                local aabb = ee.bounding.scene_aabb
                if aabb ~= mc.NULL then
                    calc_camera_t(queue_name, aabb) 
                end              
            end
            ::continue::
        end
        g:disable(enable_tag)
    end      
end

function iUiRt.open_rt_lighting(rt_name, light_path)
    if iUiRt.get_group_id(rt_name) then
        local queue_name = rt_name .. "_queue"
        local gid = iUiRt.get_group_id(rt_name)
        local g = ecs.group(gid)
    
        g:enable "view_visible"
        g:enable "scene_update"
    
        local light = g:create_instance(light_path)
        light.on_ready = function (inst)
            local alleid = inst.tag['*']
            for _, eid in ipairs(alleid) do
                local ee <close> = w:entity(eid, "visible_state?in")
                if ee.visible_state then
                    ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                    ivs.set_state(ee, queue_name, true)
                end
            end
        end
        world:create_object(light)  
    end      
end 

function iUiRt.close_rt_lighting(rt_name)
    if iUiRt.get_group_id(rt_name) then
        local gid = iUiRt.get_group_id(rt_name)
        local g = ecs.group(gid)
        local enable_tag = rt_name .. "_queue_visible"
        local select_tag = enable_tag .. " name?in"
        g:enable(enable_tag)
        for ee in w:select(select_tag) do
            if not ee then
                goto continue
            end
            if ee.name and ee.name == "skybox_rt" then
                w:remove(ee)
                goto continue
            end
            ::continue::
        end
        g:disable(enable_tag)
        for ee in w:select "light:in name?in visible?update" do
            if ee.name == "directional_light_rt" then
                ee.visible = false
            end
        end
    end      
end 

function ui_rt_sys:data_changed()
    for gid, name in pairs(g2rt_table) do
        local g = ecs.group(gid)
        local obj = name.."_obj"
        local queue_visible = name.."_queue_visible"
        g:enable(obj)
        local s_select = ("%s%s%s"):format(obj, " render_object", " visible_state?in")
        local s_visible = ("%s%s"):format(queue_visible, "?out")
        for e in w:select(s_select) do
            w:extend(e, s_visible)
            e[queue_visible] = true
        end        
    end

    for rt_name, _ in pairs(focused_rt_table) do
        iUiRt.adjust_camera(rt_name)
    end
end
