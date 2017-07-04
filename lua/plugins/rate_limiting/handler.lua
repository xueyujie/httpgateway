--依赖模块
--acl
local cjson = require "cjson"
local limit_req = require "resty.limit.req"

local BasePlugin = require "plugins.base_plugin"
local utils = require "tools.utils"
local cache_common = require "dao.cache.common"

local json_encode = cjson.encode


local RateLimitingHandler = BasePlugin:extend()

function RateLimitingHandler:new()
    RateLimitingHandler.super.new(self, "rate_limiting")
end

function RateLimitingHandler:access(singletons)
    RateLimitingHandler.super.access(self)

    local source = ngx.ctx.source
    local service = ngx.ctx.service_name

    local service_config = cache_common.get_service_config(service, singletons)
    if service_config == nil then
        ngx.log(ngx.ERR, "service config no exist:(", service, ")")
        return ngx.exit(ngx.HTTP_FORBIDDEN)
    end
    ngx.log(ngx.DEBUG, "plugin[" .. self._name .. "],key[" .. service .. "], config: ", json_encode(service_config))

    local req_under = tonumber(service_config['under'])
    local req_burst = tonumber(service_config['burst'])
    if req_under ~= nil and req_under ~= "" then
        if req_burst == nil then
            req_burst = 100 --如果为空设置为100,防止两次请求时间间隔小于1ms被拒绝的情况
        end

        -- 限制请求速率为200 req/sec，并且允许100 req/sec的突发请求
        -- 就是说我们会把200以上300一下的请求请求给延迟
        -- 超过300的请求将会被拒绝
        local lim, err = limit_req.new("my_limit_req_store", req_under, req_burst)
        --申请limit_req对象失败,共享内存未定义
        if not lim then
            ngx.log(ngx.ERR, "failed to instantiate a resty.limit.req object: ", err)
            return ngx.exit(500)
        end

        -- 下面代码针对每一个单独的请求
        -- 使用目标+url作为key
        local limit_key = ngx.var.request_uri .. service
        local delay, err = lim:incoming(limit_key, true)

        --如果拒绝delay为nil
        if not delay then
            if err == "rejected" then
                ngx.status = 429
                ngx.print("Too Many Requests.")
                return
            end
            --共享内存获取相关问题
            ngx.log(ngx.ERR, "failed to limit req: ", err)
            return ngx.exit(500)
        end

        if delay >= 0.001 then
            -- 第二个参数(err)保存着超过请求速率的请求数
            -- 例如err等于31，意味着当前速率是231 req/sec
            -- local excess = err

            -- 当前请求超过200 req/sec 但小于 300 req/sec
            -- 因此我们sleep一下，保证速率是200 req/sec，请求延迟处理
            ngx.sleep(delay)
        end
    end
end


return RateLimitingHandler