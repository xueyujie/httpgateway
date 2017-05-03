--依赖模块
--auth
local BasePlugin = require "plugins.base_plugin"
local cache_common = require "dao.cache.common"
local utils = require "tools.utils"

local ACLHandler = BasePlugin:extend()

function ACLHandler:new()
    ACLHandler.super.new(self, "acl")
end

function ACLHandler:access(singletons)
    ACLHandler.super.access(self)

    --没有配置直接return
    local config = cache_common.get_service_plugin_config(service_name, singletons)
    if not config.acl then
        return
    end

    local consumer_name = ngx.ctx.source
    local service_name = ngx.ctx.service_name

    local acl = false
    local acl_config = utils.get_location_conf(config.acl)
    if acl_config then
        for _, allow_acl in ipairs(acl_config.consumers) do
            if allow_acl == consumer_name then
                acl = true
                break
            end
        end
        if acl == false then
            ngx.log(ngx.ERR, "发起方", consumer_name, "不允许访问", service_name)
            return ngx.exit(ngx.HTTP_FORBIDDEN)
        end
    end
end



return ACLHandler