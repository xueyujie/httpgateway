local cjson = require "cjson"
local utils = require "tools.utils"
local singletons = require "singletons"

local encode_json = cjson.encode

local _M = {}

function _M.get_service_plugin_config(service_name, singletons)
    local plugins_config = {}
    if singletons.service_config[service_name] and singletons.service_config[service_name].plugins then
        local plugins = singletons.service_config[service_name].plugins
        for plugin_name, conf in pairs(plugins) do
            plugins_config[plugin_name] = utils.json_decode(conf)
        end
    end
    return plugins_config
end

function _M.set_service_config()
    local service_conf_file = io.open("conf/service_data.json", "r")
    singletons.service_config = utils.json_decode(service_conf_file:read("*a"))
    service_conf_file:close()
    ngx.log(ngx.INFO, "初始serice_conf_file配置:", encode_json(singletons.service_config))
end

function _M.get_service_config(service_name, singletons)
    if singletons.service_config[service_name] then
        return singletons.service_config[service_name]
    end
end

return _M
