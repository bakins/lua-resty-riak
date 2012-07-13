local _M = {}

-- I'm not real sure how we get errors from riak via pb??

-- pb is pure Lua.  The interface is pretty easy, but we can switch it out if needed.
local pb = require "pb"

-- riak_kv.proto should be in the include path
local riak_kv = require "riak_kv"

local RpbGetReq = riak_kv.RpbGetReq
local RpbGetResp = riak_ks.RpbGetResp
local RpbPutReq = riak_kv.RpbPutReq
local RpbPutResp = riak_kb.RpbPutResp

local client_mt = {}
local bucket_mt = {}
local object_mt = {}

local insert = table.insert
local tcp = ngx.socket.tcp
local mod = math.mod

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
    setmetatable(r, client_mt)
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

function client_mt.bucket(self, name)
    local b = {
        name = name,
        client = self,
        sock = tcp()
    }
    rr_connect(self)
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

function bucket_mt.get(self, key)
    local req = {
        bucket = self.name,
        key = key
    }
    
    -- XXX: error checking??
    local msg = RpbGetReq(req)
    local bin = msg:Serialize()
    -- is #bin correct here? serialize shoudlr eturn a len, but it doesn't...
    local bytes, err = sock:send({ #bin, bin })
    if not bytes then
        return nil, err
    end
    
    -- length is an integer at beginning
    local bytes, err = sock:receive(4)
    if not bytes then
        return nil, err
    end
    bytes = tonumber(bytes)
    if not bytes then
        return nil, "unable to convert length to a number"
    end
    local msg, err = sock:receive(bytes)
    if not msg then
        return nil, err
    end
    
    local response, off = RpbGetResp():Parse(msg)
    -- response is a RpbGetResp

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
    
    -- XXX: error checking??
    local msg = RpbPutReq(request)
    local bin = msg:Serialize()
    -- is #bin correct here? serialize shoudl return a len, but it doesn't seem to...
    local bytes, err = sock:send({ #bin, bin })
    if not bytes then
        return nil, err
    end
    
    -- length is an integer at beginning
    local bytes, err = sock:receive(4)
    if not bytes then
        return nil, err
    end
    bytes = tonumber(bytes)
    if not bytes then
        return nil, "unable to convert length to a number"
    end
    local msg, err = sock:receive(bytes)
    if not msg then
        return nil, err
    end
    
    local response, off = RpbPutResp():Parse(msg)
    -- response is a RpbPutResp
    -- we don't do anything with response currently...

    return self, nil
end

function object_mt.reload(self, force)
end


return _M
