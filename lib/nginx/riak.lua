local _M = {}

_M._VERSION = '0.0.1'

-- https://wiki.basho.com/PBC-API.html
-- https://github.com/basho/riak_pb

-- this is insired by the riak ruby client

local mt = {}

local client = require "nginx.riak.client"

-- servers should be in the form { {:host => host/ip, :port => :port }
function _M.new(servers, options)
    options = options or {}
    local r = {
        servers = {},
        _current_server = 1,
        timeout = options.timeout,
        keepalive_timeout = options.keepalive_timeout,
        keepalive_pool_size = options.keepalive_pool_size,
        really_close = options.really_close
    }
    servers = servers or {{ host = "127.0.0.1", port = 8087 }}
    for _,server in ipairs(servers) do
        if "table" == type(server) then
            insert(r.servers, { host = server.host or "127.0.0.1", port = server.port or 8087 })
        else
            insert(r.servers, { host = server, port = 8087 })
        end
    end
    
    setmetatable(r, { __index = mt })
    return r
end

function mt.connect(self)
    return client.connect(self)
end

return _M
