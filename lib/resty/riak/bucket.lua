local _M = {}

local riak_object = require "resty.riak.object"
local riak_client = require "resty.riak.client"

local riak_object_new = riak_object.new
local function new(self, key)
    return riak_object_new(self, key)
end

function _M.new(client, name)
    local self = {
        name = name, 
        client = client, 
	new = new
    }
    return setmetatable(self, { __index = _M })
end

local riak_client_get_object = riak_client.get_object
local riak_object_load = riak_object.load

function _M.get(self, key)
    local object, err = riak_client_get_object(self.client, self.name, key)
    if object then
	return riak_object_load(self, key, object)
    else
	return nil, err
    end
end

function _M.get_or_new(self, key)
    local object, err = riak_client_get_object(self.client, self.name, key)
    if not object then
	if "not found" == err then
	    return riak_object_new(self, key)
	else
	    return nil, err
	end
    else
	return riak_object_load(object)
    end
end

local riak_client_delete_object = riak_client.delete_object

function _M.delete(self, key)
    return riak_client_delete_object(self.client, self.name, key)
end

return _M
