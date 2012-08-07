local _M = {}

local mt = {}

local riak = require "resty.riak"

local insert = table.insert

local function connect(self)
    local servers = self.servers
    local ok, err
    for i=1,self.retries do
        local curr = mod(self.riak._current_server + 1, #servers) + 1
        self._current_server = curr
        local server = servers[curr]

        self.riak = riak.new()
        if self.timeout then
            self.riak:set_timeout(self.timeout)
        end
        ok, err = self.riak:connect(server.host, server.port)
        if ok then
            self.open = true
            setmetatable(self, { __index = self.riak })
            break
        end
    end
    return ok, err
end

local function close(self, really_close)
    if not self.riak then
        return nil, "not initialized"
    end
    if not self.open then
        return nil, "closed"
    end
    self.open = false
    if really_close or self.really_close then
        return self.riak:close()
    else
        if self.keepalive_timeout or self.keepalive_pool_size then
            return self.riak:set_keepalive(self.keepalive_timeout, self.keepalive_pool_size)
        else
            return self.riak:set_keepalive()
        end
    end
end

-- servers should be in the form { {:host => host/ip, :port => :port }
function _M.new(servers, options)
    options = options or {}
    local self = {
        servers = {},
        _current_server = 1,
        timeout = options.timeout,
        keepalive_timeout = options.keepalive_timeout,
        keepalive_pool_size = options.keepalive_pool_size,
        really_close = options.really_close,
        retries = options.retries or 1,
        open = false
    }
    if self.retries <= 0 then
        self.retries = 1
    end
    servers = servers or {{ host = "127.0.0.1", port = 8087 }}
    for _,server in ipairs(servers) do
        if "table" == type(server) then
            insert(self.servers, { host = server.host or "127.0.0.1", port = server.port or 8087 })
        else
            insert(self.servers, { host = server, port = 8087 })
        end
    end
    
    self.connect = connect
    self.close = close
    --setmetatable(r, { __index = mt })
    return r
end

return _M
