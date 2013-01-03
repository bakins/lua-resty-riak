local _M = {}
_M._VERSION = '0.1.0'

local client = require("resty.riak.client")
_M.new = client.new

return _M
