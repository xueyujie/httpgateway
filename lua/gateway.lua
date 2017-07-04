local cjson = require "cjson"

local utils = require "tools.utils"
local cache_common = require "dao.cache.common"
local singletons = require "singletons"

local tab_insert = table.insert
local ngx_req = ngx.req
local ngx_req_get_headers = ngx_req.get_headers


local function load_plugins(config)

    local sorted_plugins = {}
    for _, name in ipairs(config) do
        local ok, handler = utils.load_module_if_exists("plugins." .. name .. ".handler")

        if ok then
            sorted_plugins[#sorted_plugins + 1] = {
                name = name,
                handler = handler(),
            }
            ngx.log(ngx.INFO, "loads succ:", "plugins." .. name)
        else
            ngx.log(ngx.ERR, "loads error:", "plugins." .. name .. ".handler" .. handler)
        end
    end

    return sorted_plugins
end


local gateway = {}

function gateway.init()
    -- 加载插件
    singletons.config = {"auth","rate_limiting"}
    singletons.loaded_plugins = load_plugins(singletons.config)
    -- 加载服务配置
    cache_common.set_service_config()
end

function gateway.init_worker()
    for _, plugin in ipairs(singletons.loaded_plugins) do
        plugin.handler:init_worker(singletons)
    end
end

function gateway.access()
    --确认目标应用
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

    for _, plugin in ipairs(singletons.loaded_plugins) do
        plugin.handler:access(singletons)
    end
end


function gateway.body_filter()
    if ngx.ctx.service_name == nil then
        return
    end

    for _, plugin in ipairs(singletons.loaded_plugins) do
        plugin.handler:body_filter(singletons)
    end
end

return gateway