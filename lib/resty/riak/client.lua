local _M = {}

local pb = require "pb"
local struct = require "struct"
local riak = pb.require "riak"
local riak_kv = pb.require "riak_kv"

local rbucket = require "resty.riak.bucket"
local robject = require "resty.riak.object"

local spack, sunpack = struct.pack, struct.unpack

local mt = { }

local ErrorResp = riak.RpbErrorResp()

local function send_request(sock, msgcode, encoder, request)
    local msg = encoder(request)
    local bin = msg:Serialize()
    
    local info = spack(">IB", #bin + 1, msgcode)
    
    local bytes, err = sock:send(info .. bin)
    if not bytes then
        return nil, err
    end
    bytes, err, partial = sock:receive(5)
    if not bytes then
        return nil, err
    end
    
    local length, msgcode = sunpack(">IB", bytes)
    
    bytes = length - 1
    local response = nil
    if bytes > 0 then 
        response, err = sock:receive(bytes)
        if not response then
            return nil, err
        end
    end
    
    if msgcode == 0 then
        local errmsg = ErrorResp(response)
        if errmsg and 'table' == type(errmsg) then
            response = errmsg['errmsg']
        end
        return nil, response
    end
    return msgcode, response
end
    
function _M.new()
    local sock, err = ngx.socket.tcp()
    if not sock then
        return nil, err
    end
    local self = {
        sock = sock
    }
    return setmetatable(self, { __index = mt })
end

-- Generic socket functions

function mt.set_timeout(self, timeout)
    return self.sock:settimeout(timeout)
end

function mt.connect(self, ...)
    return self.sock:connect(...)
end

function mt.set_keepalive(self, ...)
    return self.sock:setkeepalive(...)
end

function mt.get_reused_times(self)
    return self.sock:getreusedtimes()
end

function mt.close(self)
    return self.sock:close()
end


function _M.bucket(self, name)
    return rbucket.new(self, name)
end

local PutReq = riak_kv.RpbPutReq
function _M.store_object(self, object)
    local sock = self.sock

    local request = {
        bucket = object.bucket.name,
        key = object.key,
        content = {
            value = self.value or "",
            content_type = object.content_type,
            charset = object.charset,
            content_encoding = object.content_encoding, 
            usermeta = object.meta
        }
    }

    -- 11 = PutReq
    local msgcode, response = send_request(sock, 11, PutReq, request)
    if not msgcode then
        return nil, response
    end

    -- 12 = PutResp
    if msgcode == 12 then
        -- unless we want to include body (which we do not currently support) then it's empty
        return true
    else
        return nil, "unhandled response type"
    end
end

function _M.reload_object(self, object)
end

local DelReq = riak_kv.RpbDelReq
function _M.delete_object(self, bucket, key)
    local sock = self.sock
    
    local request = { 
        bucket = bucket.name, 
        key = key 
    }
    
    -- 13 = DelReq
    local msgcode, response = send_request(sock, 13, DelReq, request)
    if not msgcode then
        return nil, response
    end

    -- 14 = DelResp
    if msgcode == 14 then
        return true
    else
        return nil, "unhandled response type"
    end
end

local GetReq = riak_kv.RpbGetReq
local GetResp = riak_kv.RpbGetResp()
function _M.get_object(self, bucket, key)
    local sock = self.sock
    local request = {
        bucket = bucket.name,
        key = key
    }
    
    -- 9 = GetReq
    local msgcode, response = send_request(sock, 9, GetReq, request)
    if not msgcode then
        return nil, response
    end
    
    -- 10 = GetReq
    if msgcode ==  10 then
        if not response then
            return nil, "not found"
        end
        response = GetResp:Parse(response)
        
        return robject.load(bucket, key, response)
    else
        return nil, "unhandled response type"
    end
end

return _M
