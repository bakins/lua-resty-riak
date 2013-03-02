# lua-resty-riak #

lua-resty-riak - Lua riak protocol buffer client driver for the ngx_lua
based on the cosocket API.

Originally based on the
[lua-resty-memcached](https://github.com/agentzh/lua-resty-memcached)
library.

Influence by [riak-client-ruby](https://github.com/basho/riak-ruby-client/)

## Status ##

This library is currently _alpha_ quality. It passes all its unit
tests. A few billion requests per day are handled by it however.

Users are encouraged to test the code in the `refactor` branch. It is a complete rewrite. The internal code has been greatly simplified while providing the same functionality. It, however, has not received the same amount of testing.

## Description ##

This Lua library is a riak protocol buffer client driver for the [ngx_lua nginx module](http://wiki.nginx.org/HttpLuaModule)

This Lua library takes advantage of ngx_lua's cosocket API, which ensures
100% nonblocking behavior.

Note that at least [ngx\_lua 0.5.0rc29](https://github.com/chaoslawful/lua-nginx-module/tags) or [ngx\_openresty 1.0.15.7](http://openresty.org/#Download) is required.

Depends on the following Lua modules:

* lua-pb - https://github.com/Neopallium/lua-pb
* struct - http://www.inf.puc-rio.br/~roberto/struct/
 
## Synopsis ##

    lua_package_path "/path/to/lua-resty-riak/lib/?.lua;;";
    location /t {
        content_by_lua '
            require "luarocks.loader"
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
            local rc, err = object:store()
            ngx.say(rc)
            local object, err = bucket:get("1")
            if not object then
                ngx.say(err)
            else
                ngx.say(object.value)
            end
            client:close()
        ';
    }

## Methods ##

### Module Methods ###

#### new ####
syntax: `local riak, err = riak.new()`

Creates a riak object. In case of failures, returns `nil` and a
string describing the error.

### Instance Methods ###

#### connect ####
`syntax: local ok, err = riak:connect(host, port)`

Attempts to connect to the remote host and port.

Before actually resolving the host name and connecting to the remote backend, this method will always look up the connection pool for matched idle connections created by previous calls of this method.

#### set_timeout ####
`syntax: riak:set_timeout(time)`

Sets the timeout (in ms) protection for subsequent operations, including the `connect` method.

#### set_keepalive ####
`syntax: local ok, err = riak:set_keepalive(max_idle_timeout, pool_size)`

Keeps the current riak connection alive and put it into the ngx_lua cosocket connection pool.

You can specify the max idle timeout (in ms) when the connection is in the pool and the maximal size of the pool every nginx worker process.

In case of success, returns `1`. In case of errors, returns `nil` with a string describing the error.

#### get\_reused\_times ####
`syntax: local times, err = riak:get_reused_times()`

This method returns the (successfully) reused times for the current connection. In case of error, it returns `nil` and a string describing the error.

If the current connection does not come from the built-in connection pool, then this method always returns `0`, that is, the connection has never been reused (yet). If the connection comes from the connection pool, then the return value is always non-zero. So this method can also be used to determine if the current connection comes from the pool.


#### close ####
`syntax: local ok, err = riak:close()`

Closes the current riak connection and returns the status.

In case of success, returns `1`. In case of errors, returns `nil` with a string describing the error.


#### bucket ####
syntax: `local bucket = client:bucket(name)`

Returns:

* A riak bucket object

Note: this uses `resty.bucket.new`

### Bucket Methods ###

#### new ####
syntax: `local bucket = resty.riak.bucket.new(riak, name)`

Module Function.

Create a new bucket object. client must be a valid, open `resty.riak`
object.  In pratice, `riak:bucket(name)` is preferred.

#### new ####
syntax: `local object = bucket:new(key)`
 
Create a new riak value object .

Note: this uses `resty.riak.object.new`

#### get ####
syntax: `local object, err = bucket:get(key)`

Retrieve an object from the bucket.

Returns:

* object - a riak value object.
* err - error emssage if any. _"not found"_ means the key could not be
  found.
  
#### get\_or\_new ####
syntax: `local object, err = bucket:get_or_new(key)`

Convinience method.

Retrieve an object if it exists or create it if it does not.

#### delete ####
syntax: `local rc, err = bucket:delete(key)`

Delete an object.

Returns:

* rc - status of delete. Note: this returns true even if the object
  did not exist before this call.
* err - error message if any.

### Object Methods ####

#### new ####
syntax: `local object =resty.riak.object.new(bucket, key)`

Create a new riak value object. This does **not** persist to the
server(s) until `object:store()` is called. Generally, `bucket:new(key)`
is prefered.

In addition to the methods listed here, an object also has these
fields:

* value - _required_ the actual value. Should be a Lua string. _""_ is
  a valid "empty" value.
* content\_type - _required_ mime type of the object. There is no
  default.
*  charset 
* content\_encoding
* meta - key/value table of arbitrary user meta data. This can **not**
contain nested tables and all keys and values should be simple
strings.

The fileds marked as required **must** be present when
`object:store()` is called to be successfully stored.

#### get ####
syntax: `local object, err = resty.riak.object.get(bucket, key)`

Retrive an object. `bucket:get(key)` is generally preferred.

#### store ####
syntax: `local rc, err = object:store()`

Persist an object to riak.  See the new method for field requirements.

Returns:

* rc - status of store. a _true_ value on success.
* err - error message if any

#### delete ####
syntax: `local rc, err = object:delete()`

Remove an object. see `bucket:delete(key)` as this is just a wrapper
around it.

## Limitations ##

* This library cannot be used in code contexts like *set_by_lua*, *log_by_lua*, and
*header_filter_by_lua* where the ngx\_lua cosocket API is not available.
* The `resty.riak` object instances  cannot be stored in a Lua variable at the Lua module level,
because it will then be shared by all the concurrent requests handled by the same nginx
 worker process (see [Data Sharing within an Nginx Worker](http://wiki.nginx.org/HttpLuaModule#Data\_Sharing\_within\_an\_Nginx_Worker) ) and
result in bad race conditions when concurrent requests are trying to use the same instances.
You should always initiate these objects in function local
variables or in the `ngx.ctx` table. These places all have their own data copies for
each request.


## TODO ##

## Author ##
Brian Akins <brian@akins.org>

Heavily influenced by  Zhang "agentzh" Yichun (章亦春) <agentzh@gmail.com>.

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2012, by Brian Akins <brian@akins.org>.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## See Also ##
* [ngx_lua module](http://wiki.nginx.org/HttpLuaModule)
* [riak-client-ruby](https://github.com/basho/riak-ruby-client/)
* [Riak Protocol Buffer API](https://wiki.basho.com/PBC-API.html)
