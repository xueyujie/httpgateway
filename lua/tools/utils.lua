local cjson = require "cjson"
local lm = require "resty.location.match"

local tinsert = table.insert


local _M = {}

--str：待分割字符串
--delimiter：分割符，
function _M.split(str, delimiter)
    if str == nil or str == '' or delimiter == nil then
        return nil
    end

    local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        tinsert(result, match)
    end
    return result
end

function _M.json_decode(str)
    local ok, json_value = pcall(cjson.decode, str)
    if not ok then
        json_value = nil
    end
    return json_value
end

--- Try to load a module.
-- Will not throw an error if the module was not found, but will throw an error if the
-- loading failed for another reason (eg: syntax error).
-- @param module_name Path of the module to load (ex: kong.plugins.keyauth.api).
-- @return success A boolean indicating wether the module was found.
-- @return module The retrieved module, or the error in case of a failure
function _M.load_module_if_exists(module_name)
    local status, res = pcall(require, module_name)
    if status then
        return true, res
        -- Here we match any character because if a module has a dash '-' in its name, we would need to escape it.
    else
        return false, res
    end
end

function _M.get_location_conf(conf)
    if conf then
        local location_match = {}
        for match, _ in pairs(conf) do
            location_match[#location_match + 1] = match
        end
        local location = lm:match_location(ngx.var.uri, location_match)

        if location then
            return conf[location], location
        end
    end
end

function _M.get_location(location_list)
    return lm:match_location(ngx.var.uri, location_list)
end

function _M.get_real_ip()
    local ip = ngx.var.remote_addr
    local x_forwarded_for = ngx.var.http_x_forwarded_for
    local real_ip = ngx.var.http_x_real_ip
    if real_ip then
        ip = real_ip
    elseif x_forwarded_for then
        ip = _M.split(x_forwarded_for, ",")[1]
    end
    ngx.log(ngx.DEBUG, "remote_addr:", ngx.var.remote_addr, ",forward_for:", x_forwarded_for, ",real_ip:", real_ip, ",ip:", ip)

    return ip
end

function _M.table_is_array(t)
    if type(t) ~= "table" then return false end
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true
end



return _M