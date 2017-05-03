--依赖模块
local cjson = require "cjson"
local iputils = require "resty.iputils"
local BasePlugin = require "plugins.base_plugin"
local utils = require "tools.utils"
local cache_common = require "dao.cache.common"

local json_encode = cjson.encode

local IpRestrictionHandler = BasePlugin:extend()

function IpRestrictionHandler:new()
    IpRestrictionHandler.super.new(self, "ip_restriction")
end

function IpRestrictionHandler:access(singletons)
    IpRestrictionHandler.super.access(self)

    --没有配置直接return
    local config = cache_common.get_service_plugin_config(service_name, singletons)
    if not config.ip_restriction then
        return
    end

    local block = false
    local service_name = ngx.ctx.service_name
    local client_ip = utils.get_real_ip()

    if not client_ip then
        ngx.log(ngx.ERR, "ip获取失败")
        return ngx.exit(ngx.HTTP_FORBIDDEN)
    end

    local ip_config = utils.get_location_conf(config.ip_restriction)
    ngx.log(ngx.DEBUG, "plugin[" .. self._name .. "],key[" .. service_name .. "], config: " .. json_encode(ip_config) .. ",client:" .. client_ip)

    if ip_config.blacklist and #ip_config.blacklist > 0 then
        block = iputils.ip_in_cidrs(client_ip, iputils.parse_cidrs(ip_config.blacklist))
    end

    if ip_config.whitelist and #ip_config.whitelist > 0 then
        block = not iputils.ip_in_cidrs(client_ip, iputils.parse_cidrs(ip_config.whitelist))
    end

    if block then
        ngx.log(ngx.ERR, "ip:" .. client_ip .. "不允许被访问" .. service_name)
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end
end


return IpRestrictionHandler