--
-- Created by IntelliJ IDEA.
-- User: lvyalin
-- Date: 2017/4/27
-- Time: 下午3:50
-- To change this template use File | Settings | File Templates.
--
--args

local BasePlugin = require "plugins.base_plugin"
local cache_common = require "dao.cache.common"
local singletons = require "singletons"

local rulematch = ngx.re.find
local unescape = ngx.unescape_uri

local WafHandler = BasePlugin:extend()

function WafHandler:new()
    WafHandler.super.new(self, "waf")
end


--WAF return
local function waf_output()
    ngx.header.content_type = "text/html"
    ngx.status = ngx.HTTP_FORBIDDEN
    ngx.say([[
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="Content-Language" content="zh-cn" />
<title>waf 403</title>
</head>
<body>
<h1 align="center">waf 403 forbidden</h1>
</body>
</html>
]])
    ngx.exit(ngx.status)
end

--deny user agent
local function user_agent_attack_check()
    local user_agent_rules = cache_common.get_waf_config("useragent", singletons)
    local user_agent = ngx.var.http_user_agent
    if user_agent ~= nil then
        for _,rule in pairs(user_agent_rules) do
            if rule ~="" and rulematch(user_agent,rule,"jo") then
                waf_output()
                return true
            end
        end
    end
    return false
end

--deny cookie
local function cookie_attack_check()
    local cookie_rules = cache_common.get_waf_config("cookie", singletons)
    local user_cookie = ngx.var.http_cookie
    if user_cookie ~= nil then
        for _,rule in pairs(cookie_rules) do
            if rule ~="" and rulematch(user_cookie,rule,"jo") then
                waf_output()
                return true
            end
        end
    end
    return false
end

--deny url
local function url_attack_check()
    local url_rules = cache_common.get_waf_config("url", singletons)
    local req_uri = ngx.var.request_uri
    for _,rule in pairs(url_rules) do
        if rule ~="" and rulematch(req_uri,rule,"jo") then
            waf_output()
            return true
        end
    end
    return false
end

--deny url args
local function url_args_attack_check()
    local args_rules = cache_common.get_waf_config("args", singletons)
    local req_args = ngx.req.get_uri_args()

    for _,rule in pairs(args_rules) do
        for _, val in pairs(req_args) do
            if type(val) == 'table' then
                local args_data = table.concat(val, " ")
            else
                local args_data = val
            end
            if args_data and type(args_data) ~= "boolean" and rule ~="" and rulematch(unescape(args_data),rule,"jo") then
                waf_output()
                return true
            end
        end
    end
    return false
end

function WafHandler:access(singletons)
    if user_agent_attack_check() then
    elseif cookie_attack_check() then
    elseif url_attack_check() then
    elseif url_args_attack_check() then
    else
        return
    end
end


return WafHandler