local riak = require "resty.riak"
local client = riak.new()
local ok, err = client:connect("127.0.0.1", 8087)
if not ok then
    ngx.log(ngx.ERR, "connect failed: " .. err)
end
local bucket = client:bucket("test")
local props, err = bucket:properties("test")
ngx.say(type(props))
ngx.say(type(props.n_val))
ngx.say(type(props.allow_mult))
local rc, err = bucket:set_properties({ n_val = 2 })
ngx.say(tostring(rc))
client:close()
