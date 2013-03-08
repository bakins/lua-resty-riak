local require = require
local setmetatable = setmetatable
local error = error

local _M = require("resty.riak.helpers").module()

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

return _M
