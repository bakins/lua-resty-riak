 local riak = require "resty.riak"
 local client = riak.new()
 local ok, err = client:connect("127.0.0.1", 8087)
 if not ok then
     ngx.log(ngx.ERR, "connect failed: " .. err)
 end
 local id, err = client:get_client_id()
 ngx.say(type(id))
 ngx.say(err)
 client:close()
