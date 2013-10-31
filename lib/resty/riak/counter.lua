--- Riak counter object. Can only be used with resty.riak created client.
-- These are generally just wrappers around the low level
-- @{resty.riak.client} functions
-- @see resty.riak
-- @module resty.riak.counter

local riak_client = require "resty.riak.client"
local helpers = require "resty.riak.helpers"
local setmetatable = setmetatable
local get_counter = riak_client.get_counter
local update_counter = riak_client.update_counter
local _M = helpers.module()

local function to_number(self)
end

local mt = {
    __index = _M,
    __tonumber = to_number
}

--- Create a new riak counter. This does not change anything in riak, it only sets up a Lua object.
-- Generally, @{resty.riak.bucket.counter}
-- is prefered.
-- @tparam resty.riak.bucket bucket
-- @tparam string key
-- @treturn resty.riak.counter
function _M.new(bucket, key)
    local o = {
        bucket = bucket,
        client = bucket.client,
        key = key,
    }
    return setmetatable(o, mt)
end

--- Get the value of the counter
-- @tparam resty.riak.counter self
-- @treturn number
function _M.value(self)
    return get_counter(self.client, self.bucket.name, self.key)
end

--- Decrement the counter
-- @tparam resty.riak.counter self
-- @tparam number amount the amount to decrement the counter by
-- @treturn boolean
function _M.decrement(self, amount)
    amount = amount and (0 - amount) or -1
    return update_counter(self.client, self.bucket.name, self.key, amount)
end

--- Increment the counter
-- @tparam resty.riak.counter self
-- @tparam number amount the amount to increment the counter by
-- @treturn boolean
function _M.increment(self, amount)
    amount = amount or 1
    return update_counter(self.client, self.bucket.name, self.key, amount)
end

--- Decrement the counter and return its new value
-- @tparam resty.riak.counter self
-- @tparam number amount the amount to decrement the counter by
-- @treturn number
function _M.decrement_and_return(self, amount)
    amount = amount and (0 - amount) or -1
    return update_counter(self.client, self.bucket.name, self.key, amount, { returnvalue = true })
end

--- Increment the counter and return its new value
-- @tparam resty.riak.counter self
-- @tparam number amount the amount to decrement the counter by
-- @treturn number
function _M.increment_and_return(self, amount)
    amount = amount or 1
    return update_counter(self.client, self.bucket.name, self.key, amount, { returnvalue = true })
end


return _M
