local cjson = require "cjson"


local _M = {
    status_codes = {
        HTTP_OK = 200,
        HTTP_CREATED = 201,
        HTTP_NO_CONTENT = 204,
        HTTP_BAD_REQUEST = 400,
        HTTP_UNAUTHORIZED = 401,
        HTTP_FORBIDDEN = 403,
        HTTP_NOT_FOUND = 404,
        HTTP_METHOD_NOT_ALLOWED = 405,
        HTTP_CONFLICT = 409,
        HTTP_UNSUPPORTED_MEDIA_TYPE = 415,
        HTTP_INTERNAL_SERVER_ERROR = 500
    }
}


local response_default_content = {
    [_M.status_codes.HTTP_UNAUTHORIZED] = function(content)
        return content or "Unauthorized"
    end,
    [_M.status_codes.HTTP_NO_CONTENT] = function(content)
        return nil
    end,
    [_M.status_codes.HTTP_NOT_FOUND] = function(content)
        return content or "Not found"
    end,
    [_M.status_codes.HTTP_INTERNAL_SERVER_ERROR] = function(content)
        return "An unexpected error occurred"
    end,
    [_M.status_codes.HTTP_METHOD_NOT_ALLOWED] = function(content)
        return "Method not allowed"
    end
}





local function send_response(status_code)
    return function(content, headers)
        if status_code >= _M.status_codes.HTTP_INTERNAL_SERVER_ERROR then
            if content then
                ngx.log(ngx.ERR, tostring(content))
            end
        end

        ngx.status = status_code
        ngx.header["Content-Type"] = "application/json; charset=utf-8"

        if headers then
            for k, v in pairs(headers) do
                ngx.header[k] = v
            end
        end

        if type(response_default_content[status_code]) == "function" then
            content = response_default_content[status_code](content)
        end


        if status_code <= _M.status_codes.HTTP_BAD_REQUEST then
            if type(content) == "table" then
                ngx.say(cjson.encode({
                    retcode = 2000000,
                    msg = 'success',
                    data = content
                }))
            else
                ngx.say(cjson.encode({
                    retcode = 2000000,
                    msg = 'success',
                }))
            end
        else
            ngx.say(cjson.encode({
                retcode = status_code,
                msg = content,
            }))
        end

        return ngx.exit(status_code)
    end
end

-- Generate sugar methods (closures) for the most used HTTP status codes.
for status_code_name, status_code in pairs(_M.status_codes) do
    _M["send_" .. status_code_name] = send_response(status_code)
end

function _M.send(status_code, body, headers)
    return send_response(status_code)(body, headers)
end

return _M