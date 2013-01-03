local _M = {}

local robject = require "resty.riak.object"

local mt = { 
    __index = _M 
}

function _M.new(client, name)
    -- cheesy...
    local self = {
        name = name, 
        client = client,
        get = _M.get_object,
        new = _M.new_object,
        get_or_new = _M.get_or_new_object,
        delete = _M.delete_object
    }
    return setmetatable(self, mt)
end

function _M.get_object(self, key)
    return self.client.get_object(self, key)
end

function _M.new_object(self, key)
    return robject.new(self, key)
end

function _M.get_or_new_object(self, key)
    local object = self.client.get_object(self, key)
    if not object then
        return robject.new(self, key)
    end
end

function _M.delete_object(self, key)
    return self.client:delete_object(self, key)
end

return _M
