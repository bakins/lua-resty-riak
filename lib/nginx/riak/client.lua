local _M = {}
-- pb is pure Lua.  The interface is pretty easy, but we can switch it out if needed.
local pb = require "pb"

-- maybe investigate http://code.google.com/p/lua-bitstring/?
require "pack"

-- riak_kv.proto should be in the include path
local riak = pb.require "nginx.riak.protos.riak"
local riak_kv = require "nginx.riak.protos.riak_kv"
local bit = require "bit"

local RpbGetReq = riak_kv.RpbGetReq
local RpbGetResp = riak_kv.RpbGetResp()
local RpbPutReq = riak_kv.RpbPutReq
local RpbPutResp = riak_kv.RpbPutResp()
local RpbDelReq = riak_kv.RpbDelReq
local RpbDelResp = riak_kv.RpbDelResp

local RpbErrorResp = riak.RpbErrorResp()


local mt = {}

local insert = table.insert
local tcp = ngx.socket.tcp
local mod = math.mod
local pack = string.pack
local unpack = string.unpack

local rbucket = require("nginx.riak.bucket")

-- bleah, this is ugly
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

-- TODO: nginx socket pool stuff?
local function rr_connect(self)
    self.sock = tcp()
    local sock = self.sock
    local servers = self.riak.servers
    
    local ok, err
    for i=1,riak.retries do
        ok, err = nil, nil
        local curr = mod(self.riak._current_server + 1, #servers) + 1
        self.riak._current_server = curr
        local server = servers[curr]
        
        if self.timeout then
            sock:settimeout(timeout)
        end
        
        ok, err = sock:connect(server.host, server.port)
        if ok then
            break
        end
    end
    if not ok then
        return nil, err
    end
    return true, nil
end

function _M.connect(riak)
    local c = {
        riak = riak
    }
    local ok, err = rr_connect(c)
    if not ok then
        return nil, err
    end
    setmetatable(c,  { __index = mt })
    return c
end

function mt.reconnect()
    self:close(true)
    local ok, err = rr_connect(c)
    if not ok then
        return nil, err
    end
    return true, nil
end

function mt.bucket(self, name)
    return rbucket.new(self, name)
end

local response_funcs = {}

function response_funcs.GetResp(msg)
    return response, off = RpbGetResp:Parse(msg)
end

function response_funcs.ErrorResp(msg)
    local response, off = RpbErrorResp:Parse(msg)
    return nil, response.errmsg, response.errcode
end

function response_funcs.PutResp(msg)
    local response, off = RpbPutResp:Parse(msg)
    -- we don't really do anything here...
    return true
end

local empty_response_okay = {
    PingResp = 1,
    SetClientIdResp = 1,
    PutResp = 1,
    DelResp = 1,
    SetBucketResp = 1
}

function mt.handle_response(client)
    local sock = client.sock
    local bytes, err, partial = sock:receive(5)
    if not bytes then
        return nil, err
    end
    
    local _, length, msgcode = unpack(bytes, ">Ib")
    local msgtype = MESSAGE_CODES[tostring(msgcode)]
    
    if not msgtype then
        return nil, "unhandled response type"
    end
    
    bytes = length - 1
    if bytes <= 0 then
        if empty_response_okay[msgtype] then
            return true, nil
        elseif "GetResp" == msgtype then
            return nil, "not found"
        else
            client:close(true)
            return nil, ("empty response" .. msgtype)
        end
    end
    -- hack: some messages can return no body on success?
    local msg, err = sock:receive(bytes)
    if not msg then
        client:close(true)
        return nil, err
    end
    
    local func = response_funcs[msgtype]
    return func(msg)
end

-- ugly...
local function send_request(client, msgcode, encoder, request)
    local msg = encoder(request)
    local bin = msg:Serialize()
    
    local info = pack(">Ib", #bin + 1, msgcode)

    local bytes, err = client.sock:send({ info, bin })
    if not bytes then
        return nil, err
    end
    return true, nil
end

local request_encoders = {
    GetReq = RpbGetReq,
    PutReq = RpbPutReq,
    DelReq = RpbDelReq
}

for k,v in pairs(request_encoders) do
    mt[k] = function(client, request) 
                       local rc, err = send_request(client, MESSAGE_CODES[k], v, request)
                       if not rc then
                           return rc, err
                       end
                       return client:handle_response()
                   end
end


function mt.close(self, really_close)
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


return _M
