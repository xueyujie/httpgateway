local cjson = require "cjson"

local utils = require "tools.utils"
local cache_common = require "dao.cache.common"
local singletons = require "singletons"

local encode_json = cjson.encode
local tab_insert = table.insert
local ngx_req = ngx.req
local ngx_req_get_headers = ngx_req.get_headers


local function load_plugins(config)

    local sorted_plugins = {}
    for _, name in ipairs(config.plugins) do
        local ok, handler = utils.load_module_if_exists("plugins." .. name .. ".handler")

        if ok then
            sorted_plugins[#sorted_plugins + 1] = {
                name = name,
                handler = handler(),
            }
            ngx.log(ngx.INFO, "加载插件:", "plugins." .. name)
        else
            ngx.log(ngx.ERR, "插件加载失败:", "plugins." .. name .. ".handler" .. handler)
        end
    end

    return sorted_plugins
end

local function iter_plugins_for_req(loaded_plugins, access_or_cert_ctx)

    local i = 0

    local function get_next()
        i = i + 1
        local plugin = loaded_plugins[i]
        if plugin then
            local service_name = ngx.ctx.service_name
            local config = cache_common.get_service_plugin_config(service_name, singletons)
            if config[plugin.name] then
                local location_list = {}
                for location, _ in pairs(config[plugin.name]) do
                    tab_insert(location_list, location)
                end
                local if_match = utils.get_location(location_list)
                if if_match then
                    ngx.log(ngx.INFO, "生效插件:", "plugins." .. plugin.name)

                    return i, plugin
                end
            end
            return get_next()
        end
    end

    return get_next
end


local gateway = {}

function gateway.init()
    local conf_file = io.open("/usr/local/openresty/nginx/conf/gateway_plugins.conf", "r")
    singletons.config = utils.json_decode(conf_file:read("*a"))
    conf_file:close()
    ngx.log(ngx.INFO, "初始config配置:", encode_json(singletons.config))

    cache_common.set_service_config()
    singletons.loaded_plugins = load_plugins(singletons.config)
end

function gateway.init_worker()
    for _, plugin in ipairs(singletons.loaded_plugins) do
        plugin.handler:init_worker(singletons)
    end
end

function gateway.access()
    --确认目标应用
    if ngx.ctx.service_name == nil then
        return
    end

    local service_name = ngx.var.x_service_name
    if cache_common.get_service_config(service_name, singletons) == nil then
        ngx.log(ngx.ERR, "目标应用:", service_name, "配置不存在")
        return ngx.exit(ngx.HTTP_FORBIDDEN)
    end
    ngx.ctx.service_name = service_name

    --确认来源
    local headers = ngx_req_get_headers()
    local source = headers["x-source"] or ''
    ngx.ctx.source = source
    ngx.var.source = source --access.log需要


    for _, plugin in iter_plugins_for_req(singletons.loaded_plugins) do
        plugin.handler:access(singletons)
    end
end


function gateway.body_filter()
    if ngx.ctx.service_name == nil then
        return
    end

    for _, plugin in iter_plugins_for_req(singletons.loaded_plugins) do
        plugin.handler:body_filter(singletons)
    end
end

function gateway.log()
    if ngx.ctx.service_name == nil then
        return
    end

    for _, plugin in iter_plugins_for_req(singletons.loaded_plugins) do
        plugin.handler:log(singletons)
    end
end

return gateway