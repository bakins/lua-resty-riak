local _M = {}

local object = require("resty.riak.object")

local mt = {}

function _M.new(client, name)
    return setmetatable({ name = name, client = client }, { __index = mt })
end

local object_new = object.new
function mt.new(self, key)
    return object_new(self, key)
end

local object_get = object.get
function mt.get(self, key)
    return object_get(self, key)
end

function mt.get_or_new(self, key)
    local o, err = self:get(key)
    if not o and "not found" == err then
        o, err = self:new(key)
    end
    return o, err
end

function mt.delete(self, key)
    return self.client:DelReq( { bucket = self.name, key = key })
end

return _M
