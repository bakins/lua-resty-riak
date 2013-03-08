local require = require
local setmetatable = setmetatable
local error = error
local type = type

local _M = require("resty.riak.helpers").module()

local riak_client = require "resty.riak.client"

local mt = { }

function _M.new(bucket, key)
    local o = {
        bucket = bucket,
	client = bucket.client,
        key = key,
        meta = {}
    }
    return setmetatable(o,  { __index = mt })
end

-- horrible name - load from a "raw" riak response.
-- general do not call youself...
function _M.load(bucket, key, response)
    local content = response.content
    if "table" == type(content) then
        content = content[1]
    else
        return nil, "bad content"
    end

    local object = {
        key = key,
        bucket = bucket,
        --vclock = response.vclock,
        value = content.value,
        charset = content.charset,
        content_encoding =  content.content_encoding,
        content_type = content.content_type,
        last_mod = content.last_mod
    }
              
    local meta = {}
    if content.usermeta then 
        for _,m in ipairs(content.usermeta) do
            meta[m.key] = m.value
        end
    end
    object.meta = meta
    return setmetatable(object, { __index = mt })
end

local riak_client_store_object = riak_client.store_object
function mt.store(self)
    return riak_client_store_object(self.client, self.bucket.name, self)
end

local riak_client_delete_object = riak_client.delete_object

function mt.delete(self)
    local key = self.key
    if not key then
        return nil, "no key"
    end
    return riak_client_delete_object(self.client, self.bucket.name, key)
end

return _M
