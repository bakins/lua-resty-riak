local require, setmetatable, error = require, setmetatable, error

local _M = {}
setfenv(1, _M)

_M._VERSION = '0.2.0'

local riak_bucket = require "resty.riak.bucket"
local riak_bucket_new = riak_bucket.new

local riak_client = require "resty.riak.client"
local riak_client_new = riak_client.new

function _M.new()
    local self = riak_client_new()
    self.bucket = riak_bucket_new
    return self
end


local class_mt = {
    -- to prevent use of casual module global variables
    __newindex = function (table, key, val)
        error('attempt to write to undeclared variable "' .. key .. '"')
    end
}

setmetatable(_M, class_mt)

return _M
