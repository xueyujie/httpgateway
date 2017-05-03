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

    --没有配置直接return
    local config = cache_common.get_service_plugin_config(service_name, singletons)
    if config.auth ~= 1 then
        return
    end

    local headers = ngx_req_get_headers()
    local source = ngx.ctx.source

    local source_config = cache_common.get_service_config(source, singletons)
    if source_config == nil then
        ngx.log(ngx.ERR, "发起方:(", source, ")配置不存在")
        return ngx.exit(ngx.HTTP_FORBIDDEN)
    end
    ngx.log(ngx.DEBUG, "plugin[" .. self._name .. "],key[" .. source .. "], config: ", json_encode(source_config))

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
        ngx.log(ngx.ERR, "header:" .. json_encode(headers) .. ",post:" .. json_encode(post_args) .. ",get:" .. json_encode(get_args))
        ngx.log(ngx.ERR, "验签失败,m=" .. m .. "," .. source .. "|" .. time .. "|secret|" .. fields_value)
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end
end


return AuthHandler