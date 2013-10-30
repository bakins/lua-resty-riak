--- Riak value object. Can only be used with resty.riak created client. These are generally just wrappers around the low level
-- @{resty.riak.client} functions
-- @see resty.riak
-- @module resty.riak.object

local require = require
local setmetatable = setmetatable
local error = error
local type = type
local ngx = ngx
local helpers = require("resty.riak.helpers")
local RpbPairs_to_table = helpers.RpbPairs_to_table
local table_to_RpbPairs = helpers.table_to_RpbPairs
local ipairs = ipairs

local _M = helpers.module()

local riak_client = require "resty.riak.client"

--- Create a new riak object. This does not change anything in riak, it only sets up a Lua object.
-- This does **not** persist to the server(s) until @{store} is called. Generally, @{resty.riak.bucket.new_object}
-- is prefered.
-- @tparam riak.resty.bucket bucket
-- @tparam string key
-- @treturn resty.riak.object
function _M.new(bucket, key)
    local o = {
        bucket = bucket,
	client = bucket.client,
        key = key,
        meta = {},
	indexes = {},
	siblings = {}
    }
    return setmetatable(o,  { __index = _M })
end

--- Create a "high level" object from a table returned by @{resty.riak.client.get_object}. This is considered a "private" function
-- @tparam resty.riak.bucket bucket
-- @tparam string key
-- @tparam table response as returned by @{resty.riak.client.get_object}
-- @treturn resty.riak.object
-- @treturn string error description
function _M.load(bucket, key, response)
    local content = response.content
    local siblings = {}

    for i=1,#content do
	local c = content[i]
	local s = {
	    value = c.value,
	    charset = c.charset,
	    content_encoding =  c.content_encoding,
	    content_type = c.content_type,
	    last_mod = c.last_mod,
	    meta = RpbPairs_to_table(c.usermeta)
	}
	siblings[i] = s
    end

    local object = {
        key = key,
        bucket = bucket,
	client = bucket.client,
	siblings = siblings
    }

    return setmetatable(object, { __index = _M })
end

function _M.content(self)
    return self.siblings[1]
end

function _M.has_siblings(Self)
    return self.siblings[1] ~= nil
end

for i,key in ipairs({"value", "charset", "content_encoding", "content_type", "last_mod", "meta"}) do
    _M[key] = function(self, sibling)
	sibling = sibling or 1
	local content = self.siblings[sibling]
	if content then
	    return content[key]
	else
	    return nil
	end
    end
end

local riak_client_store_object = riak_client.store_object
--- Persist an object to riak.
-- @tparam resty.riak.object self
-- @see resty.riak.client.store_object
function _M.store(self)
    local content = self.siblings and self.siblings[1] or self.content

    local object = {
        key = self.key,
        content = {
            value = content.value or "",
            content_type = content.content_type,
            charset = content.charset,
            content_encoding = content.content_encoding,
            usermeta = table_to_RpbPairs(content.meta),
	    indexes = table_to_RpbPairs(content.indexes)
        }
    }

    return riak_client_store_object(self.client, self.bucket.name, object)
end

local riak_client_delete_object = riak_client.delete_object
--- Delete an object
-- @treturn resty.riak.object self
-- @see resty.riak.client.delete_object
function _M.delete(self)
    local key = self.key
    if not key then
        return nil, "no key"
    end
    return riak_client_delete_object(self.client, self.bucket.name, key)
end

return _M
