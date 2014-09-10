local riak = require "resty.riak"
local client = riak.new()
local ok, err = client:connect("127.0.0.1", 8087)
if not ok then
    ngx.log(ngx.ERR, "connect failed: " .. err)
end

local bucket = client:bucket("siblings")

bucket:set_properties({ allow_mult = 1 })

local object = bucket:new("1")
object.value = "first"
object.content_type = "text/plain"
local rc, err = object:store()

if not rc then
    ngx.say(err)
end  

--- by not using the vector clock this always causes a sibling
local object = bucket:new("1")
object.value = "second"
object.content_type = "text/plain"
local rc, err = object:store()

if not rc then
    ngx.say(err)
end  

local object, err = bucket:get("1")
if not object then
    ngx.say(err)
else
    ngx.say(object.value)
end

ngx.say(object:has_siblings())

ngx.say(#object.siblings)

-- now set a value using vector clock
local vclock = object.vclock
local object = bucket:new("1")
object.value = "third"
object.content_type = "text/plain"
object.vclock = vclock
local rc, err = object:store()

if not rc then
    ngx.say(err)
end  

local object, err = bucket:get("1")
if not object then
    ngx.say(err)
else
    ngx.say(object.value)
end

ngx.say(object:has_siblings())

-- clean up after ourselves
object:delete()

client:close()

