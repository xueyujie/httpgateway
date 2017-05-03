local cjson = require "cjson"
local resty_lock = require "resty.lock"
local utils = require "tools.utils"

local gateway_data = ngx.shared.gateway_data

local _M = {}

function _M._get(key)
    return gateway_data:get(key)
end


function _M.get(key)
    local value, f = _M._get(key)
    if value then
        value = utils.json_decode(value)
    end
    return value, f
end


function _M._set(key, value, timeout)
    return gateway_data:set(key, value, timeout)
end


function _M.set(key, value, timeout)
    timeout = timeout or 0
    if value then
        value = cjson.encode(value)
    end
    return _M._set(key, value, timeout)
end


function _M.incr(key, value)
    return gateway_data:incr(key, value)
end

function _M.delete(key)
    return gateway_data:delete(key)
end

function _M.delete_all()
    gateway_data:flush_all()
    gateway_data:flush_expired()
end

function _M.get_or_set(key, cb, timeout)
    -- Try to get the value from the cache
    local value = _M.get(key)
    if value then return value end

    local lock, err = resty_lock:new("cache_locks", {
        exptime = 10,
        timeout = 5
    })
    if not lock then
        ngx.log(ngx.ERR, "could not create lock: ", err)
        return
    end

    -- The value is missing, acquire a lock
    local elapsed, err = lock:lock(key)
    if not elapsed then
        ngx.log(ngx.ERR, "failed to acquire cache lock: ", err)
    end

    -- Lock acquired. Since in the meantime another worker may have
    -- populated the value we have to check again
    value = _M.get(key)
    if not value then
        -- Get from closure
        value = cb()
        if value then
            local ok, err = _M.set(key, value, timeout)
            if not ok then
                ngx.log(ngx.ERR, err)
            end
        end
    end

    local ok, err = lock:unlock()
    if not ok and err then
        ngx.log(ngx.ERR, "failed to unlock: ", err)
    end

    return value
end


return _M
