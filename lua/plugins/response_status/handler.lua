-- 对是json的响应解包，如果是retcode为400，500的错误，记录到nginx日志
local BasePlugin = require "plugins.base_plugin"
local utils = require "tools.utils"

local re_find = ngx.re.find
local resp_headers = ngx.resp.get_headers

local err_code = { 400, 500 }

local ResponseStatusHandler = BasePlugin:extend()

function ResponseStatusHandler:new()
    ResponseStatusHandler.super.new(self, "response_status")
end

function ResponseStatusHandler:body_filter()
    ResponseStatusHandler.super.body_filter(self)
    local content_type = resp_headers()['Content-Type']
    if content_type == "application/json" then
        ngx.ctx.buffered = (ngx.ctx.buffered or "") .. ngx.arg[1]
        if ngx.arg[2] then
            ngx.ctx.resp_body = ngx.ctx.buffered
        end
    end
end

function ResponseStatusHandler:log()
    ResponseStatusHandler.super.log(self)
    local res = utils.json_decode(ngx.ctx.resp_body)
    if res ~= nil and res['retcode'] ~= nill then
        for _, code in ipairs(err_code) do
            local first = re_find(tostring(res['retcode']), tostring(code))
            if first == 1 then
                ngx.var.retcode = code
            end
        end
    end
end

return ResponseStatusHandler