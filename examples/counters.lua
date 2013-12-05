 local riak = require "resty.riak"
 local client = riak.new()
 local ok, err = client:connect("127.0.0.1", 8087)
 if not ok then
     ngx.log(ngx.ERR, "connect failed: " .. err)
 end
 local bucket = client:bucket("counters")

-- you can only use counters with allow_mult set on a bucket
 bucket:set_properties({ allow_mult = 1 })

 local counter = bucket:counter("counter")
 counter:decrement()

 local value = counter:value()
 ngx.say(type(value))

 local value = counter:decrement_and_return()
 ngx.say(type(value))

 client:close()
