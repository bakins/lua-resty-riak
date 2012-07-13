local _M = {}

_M._VERSION = '0.0.1'

-- https://wiki.basho.com/PBC-API.html

-- this is based closely on the riak ruby client

-- pb is pure Lua.  The interface is pretty easy, but we can switch it out if needed.
local pb = require "pb"

-- riak_kv.proto should be in the include path
local riak_kv = require "nginx.riak.protos.riak_kv"
local riak = require "nginx.riak.protos.riak"
local bit = require "bit"

local RpbGetReq = riak_kv.RpbGetReq
local RpbGetResp = riak_ks.RpbGetResp
local RpbPutReq = riak_kv.RpbPutReq
local RpbPutResp = riak_kb.RpbPutResp
local RpbErrorResp = riak.RpbErrorResp

local mt = {}
local client_mt = {}
local bucket_mt = {}
local object_mt = {}

local insert = table.insert
local tcp = ngx.socket.tcp
local mod = math.mod


local MESSAGE_CODES = {
    ErrorResp = "0",
    ["0"] = "ErrorResp",
    PingReq = "1",
    ["1"] = "PingReq",
    PingResp = "2",
    ["2"] = "PingResp",
    GetClientIdReq = "3",
    ["3"] = "GetClientIdReq",
    GetClientIdResp = "4",
    ["4"] = "GetClientIdResp",
    SetClientIdReq = "5",
    ["5"] = "SetClientIdReq",
    SetClientIdResp = "6",
    ["6"] = "SetClientIdResp",
    GetServerInfoReq = "7",
    ["7"] = "GetServerInfoReq",
    GetServerInfoResp = "8",
    ["8"] = "GetServerInfoResp",
    GetReq = "9",
    ["9"] = "GetReq",
    GetResp = "10",
    ["10"] = "GetResp",
    PutReq = "11",
    ["11"] = "PutReq",
    PutResp = "12",
    ["12"] = "PutResp",
    DelReq = "13",
    ["13"] = "DelReq",
    DelResp = "14",
    ["14"] = "DelResp",
    ListBucketsReq = "15",
    ["15"] = "ListBucketsReq",
    ListBucketsResp = "16",
    ["16"] = "ListBucketsResp",
    ListKeysReq = "17",
    ["17"] = "ListKeysReq",
    ListKeysResp = "18",
    ["18"] = "ListKeysResp",
    GetBucketReq = "19",
    ["19"] = "GetBucketReq",
    GetBucketResp = "20",
    ["20"] = "GetBucketResp",
    SetBucketReq = "21",
    ["21"] = "SetBucketReq",
    SetBucketResp = "22",
    ["22"] = "SetBucketResp",
    MapRedReq = "23",
    ["23"] = "MapRedReq",
    MapRedResp = "24",
    ["24"] = "MapRedResp",
    IndexReq = "25",
    ["25"] = "IndexReq",
    IndexResp = "26",
    ["26"] = "IndexResp",
    SearchQueryReq = "27",
    ["27"] = "SearchQueryReq",
    SearchQueryResp = "28",
    ["28"] = "SearchQueryResp"
}

-- servers should be in the form { {:host => host/ip, :port => :port }
function _M.new(servers, options)
    local r = {
        servers = {},
        _current_server = 1,
        timeout = options.timeout,
        keepalive_timeout = options.keepalive_timeout,
        keepalive_pool_size = options.keepalive_pool_size,
        really_close = options.really_close
    }
    for _,server in ipairs(servers) do
        insert(r.servers, { host = server.host or "127.0.0.1", server.port or 8087 })
    end
    setmetatable(r, mt)
    return r
end

-- TODO: ngixn socket pool stuff?
local function rr_connect(self)
    locla sock = self.sock
    local servers = self.client.servers
    local curr = mod(self.client._current_server + 1, #servers) + 1
    self.client._current_server = curr
    local server = servers[curr]
    local ok, err = sock:connect(server.host, server.port)
    if not ok then
        return nil, err
    end
    if self.timeout then
        sock:settimeout(timeout)
    end
    return true
end

function mt.connect(self)
    local c = {
        client = self,
        sock = tcp()
    }
    rr_connect(self)
    setmetatable(c, mt)
    return c
end

function client_mt.bucket(self, name)
    local b = {
        name = name,
        client = self
    }
    setmetatable(b, client_mt)
    return b
end

function bucket_mt.new(self, key)
    local o = {
        bucket = self,
        meta = {}
    }
    setmetatable(o, object_mt)
    return o
end

local response_funcs = {}

function response_funcs.GetResp(msg)
    local response, off = RpbGetResp():Parse(msg)
    -- we only support single gets currently
    local content = response.content[1]
    -- there is probably a more effecient way to do this    
    local o = {
        bucket = self,
        --vclock = response.vclock,
        value = content.value,
        charset = content.charset,
        content_encoding =  content.content_encoding
        content_type = content.value,
        last_mod = content.last_mod
    }
    
    local meta = {}
    for _,m in ipairs(content.usermeta) do
        meta[m.key] = m.val
    end
    
    o.meta = meta{}
    setmetatable(o, object_mt)
    return o
end

function response_funcs.ErrorResp(msg)
    local response, off = RpbGetResp():Parse(msg)
    return nil, errmsg, errcode
}

function response_funcs.PutResp(msg)
    local response, off = RpbPutResp():Parse(msg)
    -- we don't really do anything here...
    return true
end

local empty_response_okay = {
    PingResp = 1,
    SetClientIdResp = 1
    PutResp = 1,
    DelResp = 1,
    SetBucketResp = 1
}

local bor, rshift, band, lshift = bit.bor, bit.rshift, bit.band, bit.lshift
local function endian_swap(x)
    return bor(rshift(x, 24), band(lshift(x, 8), 0x00FF0000), band(rshift(x, 8), 0x0000FF00), lshift(x, 24))
end

function client_mt.handle_response(client)
    local sock = client.sock
    local bytes, err = sock:receive(5)
    if not bytes then
        return nil, err
    end
    bytes = tonumber(bytes)
    if not bytes then
        client:close(true)
        return nil, "unable to convert length to a number"
    end
    
    local msgcode = bit.band(bytes, 0x1f)
    bytes = endian_swap(bit.rshift(bytes, 4))

    -- length is an integer at beginning
    --[[
    local bytes, err = sock:receive(4)
    if not bytes then
        return nil, err
    end
    bytes = tonumber(bytes)
    if not bytes then
        client:close(true)
        return nil, "unable to convert length to a number"
    end
    -- we should receive this and unpack it...
    
    local msgcode, err = sock:receive(1)
    local msgtype = MESSAGE_CODES.msgcode
    if not msgtype then
        client:close(true)
        return nil, "unknown message code: " .. msgcode
    end
    local func = response_funcs[msgtype]
    if not func then
        client:close(true)
        return nil, "unhandled message type: " .. msgtype
    end
    --]]
    local bytes = bytes - 1
    if bytes <= 0 then
        if empty_response_okay.msgtype then
            return true, nil
        else
            client:close(true)
            return nil, "empty response"
        end
    end
    -- hack: some messages can return no body on success?
    local msg, err = sock:receive(bytes)
    if not msg then
        client:close(true)
        return nil, err
    end
    
    return func(msg)
end


-- ugly...
local function send_request(client, msgcode, encoder, request)
    -- XXX: error checking??
    local msg = encoder(request)
    local bin = msg:Serialize()
    -- is #bin correct here? serialize should return a len, but it doesn't...
    --local bytes, err = sock:send({ #bin + 1, msgcode, bin })
    local info = bor(lshift(endian_swap(#bin + 1), 4), msgcode)
    local bytes, err = sock:send({ info, bin })
    if not bytes then
        return nil, err
    end
end

local request_encoders = {
    GetResp = RpbGetReq,
    PutReq = RpbPutReq
}

for k,v in pairs(request_encoders) do
    client_mt[k] = function(client, request) 
                       return send_request(client, MESSAGE_CODES[k], v, request)
                   end
end

function bucket_mt.get(self, key)
    local request = {
        bucket = self.name,
        key = key
    }
    local client = self.client
    local rc, err = client:GetReq(request)
    if not rc then
        return rc, err
    end
    return client:handle_response()
end

function bucket_mt.get_or_new(self, key)
    local o, err = self:get(key)
    if not o and "not found" == err then
        o, err = self:new(key)
    end
    return o, err
end

function bucket_mt.close(self, really_close)
    if really_close or self.really_close then
        return self.sock:close()
    else
        if self.keepalive_timeout or self.keepalive_pool_size then
            return self.sock:setkeepalive(self.keepalive_timeout, self.keepalive_pool_size)
        else
            return self.sock:setkeepalive()
        end
    end
end

-- only support named keys for now
function object_mt.store(self)
    if not self.content_type then
        return nil, "content_type is required"
    end

    if not self.key then
        return nil, "only support named keys for now"
    end
    
    local meta = {}
    for k,v in pairs(self.meta) do
        insert(meta, { key = k, value = v })
    end

    local request = {
        bucket = self.bucket.name,
        key = self.key
        --vclock = self.vclock,
        content = {
            value = self.value,
            content_type = self.content_type,
            charset = self.charset,
            content_encoding = self.content_encoding, 
            usermeta = meta
        }
    }
    
    local client = self.bucket.client
     
    local rc, err = client:PutReq(request)
    
    local rc, err = client:handle_response()
    if rc then
        return self
    else
        return rc, err
    end
end

function object_mt.reload(self, force)
end


return _M
