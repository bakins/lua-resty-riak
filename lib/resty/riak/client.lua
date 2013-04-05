local require = require
local setmetatable = setmetatable
local error = error
local ngx = ngx
local type = type

local _M = require("resty.riak.helpers").module()

local pb = require "pb"
local struct = require "struct"
local riak = pb.require "riak"
local riak_kv = pb.require "riak_kv"

local spack, sunpack = struct.pack, struct.unpack

local ErrorResp = riak.RpbErrorResp()

local function encode_message(encoder, request)
    if request then
	local msg = encoder(request)
	local bin, errmsg = msg:Serialize()
	if not bin then
	    return nil, "serialization failed: " .. errmsg
	else
	    return bin, nil
	end
    else
	return "", nil
    end
end

local function parse_error(response)
    local errmsg = ErrorResp:Parse(response)
    if errmsg and 'table' == type(errmsg) then
	if errmsg['errmsg'] then
	    response = errmsg['errmsg']
	else
	    response = 'error'
	end
    end
    return nil, response
end
	
local function send_request(sock, msgcode, encoder, request)
    local bin, err = encode_message(encoder, request)
    
    if not bin then
	return nil, err
    end
    
    local info = spack(">IB", #bin + 1, msgcode)
    
    local bytes, err = sock:send(info .. bin)
    if not bytes then
        return nil, err
    end
    local bytes, err, partial = sock:receive(5)
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
	return parse_error(response)
    else
	return msgcode, response
    end
end
    
function _M.new()
    local sock, err = ngx.socket.tcp()
    if not sock then
        return nil, err
    end
    local self = {
        sock = sock
    }
    return setmetatable(self, { __index = _M })
end

-- Generic socket functions

function _M.set_timeout(self, timeout)
    return self.sock:settimeout(timeout)
end

function _M.connect(self, ...)
    return self.sock:connect(...)
end

function _M.set_keepalive(self, ...)
    return self.sock:setkeepalive(...)
end

function _M.get_reused_times(self)
    return self.sock:getreusedtimes()
end

function _M.close(self)
    return self.sock:close()
end

local PutReq = riak_kv.RpbPutReq
function _M.store_object(self, bucket, object)
    local sock = self.sock

    local request = {
        bucket = bucket,
        key = object.key,
        content = {
            value = object.value or "",
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

local DelReq = riak_kv.RpbDelReq
function _M.delete_object(self, bucket, key)
    local sock = self.sock
    
    local request = { 
        bucket = bucket, 
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
        bucket = bucket,
        key = key
    }
    
    -- 9 = GetReq
    local msgcode, response = send_request(sock, 9, GetReq, request)
    if not msgcode then
        return nil, response
    end
      
    -- 10 = GetResp
    if msgcode ==  10 then
        if not response or response.deleted then
            return nil, "not found"
        end
	return GetResp:Parse(response)
    else
        return nil, "unhandled response type"
    end
end

function _M.ping(self)
    -- 1 = PingReq
    local msgcode, response = send_request(self.sock, 1)
    if not msgcode then
        return nil, response
    end
    
    -- 2 - PingResp
    if msgcode == 2 then
	return true
    else
	return nil, msgcode
    end
end

local GetClientIdResp = riak_kv.RpbGetClientIdResp()
function _M.get_client_id(self)
    -- 3 = GetClientIdReq
    local msgcode, response = send_request(self.sock, 3)
    if not msgcode then
        return nil, response
    end
    
    -- 4 = GetClientIdResp
    if msgcode == 4 then
	return GetClientIdResp:Parse(response).client_id, nil
    else
        return nil, "unhandled response type"
    end
end

local GetServerInfoResp = riak.RpbGetServerInfoResp()
function _M.get_server_info(self)
    -- 7 = GetClientIdReq
    local msgcode, response = send_request(self.sock, 7)
    if not msgcode then
        return nil, response
    end
    
    -- 8 = GetServerInfoResp
    if msgcode ==  8 then
	return GetServerInfoResp:Parse(response), nil
    else
        return nil, "unhandled response type"
    end
end

local GetBucketReq = riak_kv.RpbGetBucketReq
local GetBucketResp = riak_kv.RpbGetBucketResp()
function _M.get_bucket_props(self, bucket)
    local request = {
        bucket = bucket
    }
    
    -- 19 = GetBucketReq
    local msgcode, response = send_request(self.sock, 19, GetBucketReq, request)
    if not msgcode then
        return nil, response
    end
      
    -- 20 = GetBucketResp
    if msgcode == 20 then
	return GetBucketResp:Parse(response).props, nil
    else
        return nil, "unhandled response type"
    end
end

return _M
