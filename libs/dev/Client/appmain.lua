package.path = "../Common/?.lua;../?.lua;" .. package.path  --path for the app
--TODO: find a way to set this
package.remote_search_path = "../?.lua;?.lua;../?/?.lua;../asset/?.lua" --path for the remote script

local lanes = require "lanes"
if lanes.configure then lanes.configure({with_timers = false, on_state_create = custom_on_state_create}) end
local linda = lanes.linda()
function log(name)
    local tag = "[" .. name .. "] "
    local write = io.write
    return function(fmt, ...)
        write(tag)
        write(string.format(fmt, ...))
        write("\n")
    end
end

local pack = require "pack"
function sendlog(...)
    linda:send("log", pack.pack({...}))
end

local origin_print = print
print = function(...)
    origin_print(...)
    sendlog(...)
end

local filemanager = require "filemanager"
local file_mgr = filemanager.new()

local bgfx = require "bgfx"

local lodepng = require "lodepnglua"

local bundle_home_dir = ""
local app_home_dir = ""
local g_WindowHandle = nil
local g_Width, g_Height = 0

--overwrite the old io.open function, give it the ability to search resources from server
local origin_open = io.open

local function custom_open(filename, mode, search_local_only)
    --default we don't search local only
    search_local_only = search_local_only or false


    local file = origin_open(filename, mode)


    if not file then
        local local_path = file_mgr:GetRealPath(filename)
        if local_path then
            local_path = bundle_home_dir .. "/Documents/" ..local_path
            file = origin_open(local_path, mode)
        end
    end

    if not file and not search_local_only then
        --search online
        local request = {"GET", filename}
        linda:send("request", request)

        --TODO file not exist
        --wait here
        while true do
            local key, value = linda:receive(0.05, "new file")
            if value then
                print("received msg", filename)
                --put into the id_table and file_table
                file_mgr:AddFileRecord(value[1], value[2])

                file_mgr:WriteDirStructure(bundle_home_dir.."/Documents/dir.txt")
                file_mgr:WriteFilePathData(bundle_home_dir.."/Documents/file.txt")

                print("file name", filename)
                local real_path = file_mgr:GetRealPath(value[2])
                file = origin_open(real_path, mode)
                print("real path",real_path)
                return file
            end
        end
    else
        return file
    end
end

io.open = custom_open

local function remote_searcher (name)
    --local full_path = name..".lua"
    --need to send the package search path
    print("remote requiring", name)
    local request = {"REQUIRE", name, package.remote_search_path}
    linda:send("request", request)

    while true do
        local key, value = linda:receive(0.05, "mem_data")
        if value~=nil then
            --print("receive data",type(value))
            return load(value)
        end
    end
end
table.insert(package.searchers, remote_searcher)



--project entrance
local entrance = nil

local lsocket = require "lsocket"
lanes.register("lsocket", lsocket)

local function CreateIOThread(linda, home_dir)
    local client = require "client"
    local c = client.new("127.0.0.1", 8888, linda, home_dir)
    while true do
        c:mainloop(0.1)
        --print("io mainloop updating")
        local resp = c:pop()
        if resp then
            c:process_response(resp)
        end
    end
end

local function run(path)
    if entrance then
        entrance.terminate()
        entrance = nil
    end

    local real_path = file_mgr:GetRealPath(path)
    if real_path then
        real_path = bundle_home_dir .."/Documents/" .. real_path

        entrance = dofile(real_path)
        --must have this function and these variables for init
        entrance.init(g_Width, g_Height, app_home_dir, bundle_home_dir)
    else
        --not in local, need require from distance
        --get file name
        local reverse_path = string.reverse(path)
        local slash_pos = string.find(reverse_path, "/")
        if slash_pos then
            reverse_path = string.sub(reverse_path, 1, slash_pos - 1)
        end
        reverse_path = string.reverse(reverse_path)
        --get rid of .lua
        reverse_path = string.sub(reverse_path, 1, -5)

        print("filename", reverse_path)
        --local rr, vv = pcall(require, reverse_path)
        --print("aabb",rr,vv)
        entrance = require(reverse_path)
        if entrance then
            entrance.init(g_Width, g_Height, app_home_dir, bundle_home_dir)
        end
    end

end

local bgfx_init = false
local screenshot_cache_num = 0
local function HandleMsg()
    while true do
        local key, value = linda:receive(0.05, "new file")
        if value then
            --print("received msg", value)
            --put into the id_table and file_table
            file_mgr:AddFileRecord(value[1], value[2])

            file_mgr:WriteDirStructure(bundle_home_dir.."/Documents/dir.txt")
            file_mgr:WriteFilePathData(bundle_home_dir.."/Documents/file.txt")
        else
            break
        end
    end

    while true do
        local key, value = linda:receive(0.05, "run")
        if value then
            if not bgfx_init then
                local rhwi = require "render.hardware_interface"
                rhwi.init(g_WindowHandle, g_Width, g_Height)


                bgfx.set_debug "T"
                bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)

                bgfx.set_view_rect(0, 0, 0, g_Width, g_Height)
                bgfx_init = true
            end

            --init when need to run something
            print("run", value)
            run(value)
        else
            break
        end
    end

    while true do
        local key, value = linda:receive(0.05, "screenshot_req")
        if value then
            if bgfx_init then

                bgfx.request_screenshot()
                screenshot_cache_num = screenshot_cache_num + 1
                print("request screenshot: ".. value[2].." num: "..screenshot_cache_num)
            end
        else
            break;
        end
    end
end

local function HandleCacheScreenShot()
    --if screenshot_cache_num
    --for i = 1, screenshot_cache_num do
    if screenshot_cache_num > 0 then
        local name, width, height, pitch, data = bgfx.get_screenshot()
        if name then
            --print(type(name), type(pitch), type(data))
            --print("screenshot name is "..name)
            local size =#data
            --print("screenshot size is "..size)

            screenshot_cache_num = screenshot_cache_num - 1

            --compress to png format
            --default is bgra format
            local data_string = lodepng.encode_png(data, width, height);
            print("screenshot encode size ",#data_string)
            linda:send("screenshot", {name, data_string})
            --linda:send("screenshot", {name, size, width, height, pitch, data})
        end
    end
    --end
end

function init(window_handle, width, height, app_dir, bundle_dir)
    bundle_home_dir = bundle_dir
    app_home_dir = app_dir

    g_WindowHandle = window_handle
    g_Width = width
    g_Height = height

    file_mgr:ReadDirStructure(bundle_home_dir.."/Documents/dir.txt")
    file_mgr:ReadFilePathData(bundle_home_dir.."/Documents/file.txt")


    package.loaded["winfile"].personaldir = function()
        return bundle_home_dir.."/Documents"
    end
    package.loaded["winfile"].shortname = function()
        return "fileserver"
    end

    package.loaded["winfile"].exist = function(path)
        if package.loaded["winfile"].attributes(path) then
            return true
        else
            --search on the server
            local request = {"EXIST", path}
            linda:send("request", request)

            --TODO file not exist
            --wait here
            while true do
                local key, value = linda:receive(0.05, "file exist")
                if value then
                    --value is a bool
                    print("check if exist", tostring(value))
                    return value
                end
            end
        end

        return false
    end

    --[[
    if not bgfx_init then
        local rhwi = require "render.hardware_interface"
        rhwi.init(g_WindowHandle, g_Width, g_Height)


        bgfx.set_debug "T"
        bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)

        bgfx.set_view_rect(0, 0, 0, g_Width, g_Height)
        bgfx_init = true
    end

    bgfx.request_screenshot()
    screenshot_cache_num = 1

    entrance = require "testlua_cube"
    entrance.init(width, height, app_dir, bundle_dir)
    --]]
    local client_io = lanes.gen("*",{package = {path = package.path, cpath = package.cpath, preload = package.preload}}, CreateIOThread)(linda, bundle_home_dir)
end

function mainloop()
    if entrance then
        entrance.mainloop()
    end


    HandleMsg()
    HandleCacheScreenShot()
end

function terminate()
    if entrance then
        entrance.terminate()
    end

    if bgfx_init then
        bgfx.shutdown()
    end

    --time to save files
    file_mgr:WriteDirStructure(bundle_home_dir.."/Documents/dir.txt")
    file_mgr:WriteFilePathData(bundle_home_dir.."/Documents/file.txt")
end

