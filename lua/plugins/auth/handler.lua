--依赖模块
local cjson = require "cjson"

local BasePlugin = require "plugins.base_plugin"
local utils = require "tools.utils"
local cache_common = require "dao.cache.common"

local ngx_req = ngx.req
local ngx_req_get_headers = ngx_req.get_headers
local json_encode = cjson.encode


local AuthHandler = BasePlugin:extend()

function AuthHandler:new()
    AuthHandler.super.new(self, "auth")
end

function AuthHandler:access(singletons)
    AuthHandler.super.access(self)

    local headers = ngx_req_get_headers()
    local source = ngx.ctx.source
    local service = ngx.ctx.service_name

    local source_config = cache_common.get_service_config(source, singletons)
    if source_config == nil then
        ngx.log(ngx.ERR, "source config no exist:(", source, ")")
        return ngx.exit(ngx.HTTP_FORBIDDEN)
    end
    ngx.log(ngx.DEBUG, "plugin[" .. self._name .. "],key[" .. source .. "], config: ", json_encode(source_config))

    local service_config = cache_common.get_service_config(service, singletons)
    if service_config == nil then
        ngx.log(ngx.ERR, "service config no exist:(", service, ")")
        return ngx.exit(ngx.HTTP_FORBIDDEN)
    end
    ngx.log(ngx.DEBUG, "plugin[" .. self._name .. "],key[" .. service .. "], config: ", json_encode(service_config))

    -- auth授权验证
    for _, auth in ipairs(service_config["auths"]) do
        if auth == source then
            break
        else
            ngx.log(ngx.ERR, "source no auth:(",source,")")
            ngx.exit(ngx.HTTP_FORBIDDEN)
        end
    end

    -- jwt验证
    local time = headers["x-time"] or ''
    local fields = headers["x-fields"]
    local m = headers["x-m"] or ''
    local fields_value = ""
    local post_args = ""
    local get_args = ""
    if fields ~= nil then
        ngx_req.read_body()
        post_args = ngx_req.get_post_args()
        get_args = ngx_req.get_uri_args()
        for _, field in ipairs(utils.split(fields, ",")) do
            local value = ""
            if post_args[field] then
                value = post_args[field]
            elseif get_args[field] then
                value = get_args[field]
            else
                value = ""
            end
            fields_value = fields_value .. value
        end
    end

    local auth = false
    for _, secret in ipairs(source_config["secrets"]) do
        if m == ngx.md5(source .. "|" .. time .. "|" .. secret .. "|" .. fields_value) then
            auth = true
            break
        end
    end
    if auth == false then
        ngx.log(ngx.ERR, "sercet check fail:m=" .. m .. ",source" .. source .. ",time=" .. time .. ",fields_value=" .. fields_value)
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end
end


return AuthHandler