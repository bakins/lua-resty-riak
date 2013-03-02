local _M = {}

local robject = require "resty.riak.object"

local mt = { }

function _M.new(client, name)
    local self = {
        name = name, 
        client = client
    }
    return setmetatable(self, { __index = mt })
end

function mt.get(self, key)
    return self.client:get_object(self.name, key)
end

function mt.new(self, key)
    return robject.new(self.name, key)
end

function mt.get_or_new(self, key)
    local object = self.client:get_object(self.name, key)
    if not object then
        return robject.new(self.name, key)
    end
end

function mt.delete(self, key)
    return self.client:delete_object(self.name, key)
end

return _M
