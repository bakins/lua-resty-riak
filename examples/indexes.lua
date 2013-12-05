local riak = require "resty.riak"
local client = riak.new()
local ok, err = client:connect("127.0.0.1", 8087)
if not ok then
    ngx.log(ngx.ERR, "connect failed: " .. err)
end
local bucket = client:bucket("test")
local object = bucket:new("1")
object.value = "test"
object.content_type = "text/plain"
object.indexes.foo_bin = "bar"
local rc, err = object:store()
ngx.say(rc)
if not rc then
    ngx.say(err)
end
local keys, err = bucket:index("foo_bin", "bar")
if not keys then
    ngx.say(err)
end
ngx.say(type(keys[1]))

-- index miss
local keys, err = bucket:index("foo_bin", "this should not be found")
if not keys then
    ngx.say(err)
end
ngx.say(type(keys[1]))
client:close()
