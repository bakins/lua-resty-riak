local _M = {}

local robject = require("nginx.riak.object")

local mt = {}

function _M.new(client, name)
    local b = {
        name = name,
        client = client
    }
    setmetatable(b, { __index = mt })
    return b
end

function mt.new(self, key)
    return robject.new(self, key)
end

function mt.get(self, key)
    return robject.get(self, key)
end

function mt.get_or_new(self, key)
    local o, err = self:get(key)
    if not o and "not found" == err then
        o, err = self:new(key)
    end
    return o, err
end

function mt.delete(self, key)
    local request = {
        bucket = self.name,
        key = key
    }
    return self.client:DelReq(request)
end

return _M
