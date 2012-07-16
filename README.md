# lua-nginx-riak #

lua-nginx-riak - Lua riak protocol buffer client driver for the ngx_lua
based on the cosocket API.

Originally based on the
[lua-resty-memcached](https://github.com/agentzh/lua-resty-memcached)
library.

Influence by [riak-client-ruby](https://github.com/basho/riak-ruby-client/)

## Status ##

This library is currently _alpha_ quality. It passes all its unit
tests.

## Description ##

This Lua library is a riak protocol buffer client driver for the [ngx_lua nginx module](http://wiki.nginx.org/HttpLuaModule)

This Lua library takes advantage of ngx_lua's cosocket API, which ensures
100% nonblocking behavior.

Note that at least [ngx\_lua 0.5.0rc29](https://github.com/chaoslawful/lua-nginx-module/tags) or [ngx\_openresty 1.0.15.7](http://openresty.org/#Download) is required.

This library does not follow the general interface that other nginx
resty modules use.  The interface is simplified (in the author's
opinion) and influenced by the ruby client.  It also uses the author's
general Lua style.

## Synopsis ##

    lua_package_path "/path/to/lua-resty-riak/lib/?.lua;;";
    location /t {
        content_by_lua '
            local riak = require "nginx.riak"
            local r = riak.new(nil, { timeout = 10 })
            local client = r:connect()
            local b = client:bucket("test")
            local o = b:new("1")
            o.value = "test"
            o.content_type = "text/plain"
            local rc, err = o:store()
            ngx.say(rc)
            local o, err = b:get("1")
            if not o then
                ngx.say(err)
            else
                ngx.say(o.value)
            end
            client:close()
        ';
    }

## Methods ##

### Module Methods ###

#### new ####
syntax: `local r = riak.new(serves, options)`

Creates a riak config/client object. This object can be shared among
requests and is suitable for calling in _init\_by\_lua_.
Returns `nil` on error. 

_servers_ should be in the form _{ {:host => host/ip, :port => :port }_ where port defaults
to 8087.   If multiple servers are given, they will be used in a
round-robin fashion. If _nil_, then _127.0.0.1:8087_ is used.

Options should be a table with
can contain these keys:

* keepalive_timeout - timeout argument to
  [setkeepalive](http://wiki.nginx.org/HttpLuaModule#tcpsock:setkeepalive)
* keepalive\_pool\_size    - size argument to
  [setkeepalive](http://wiki.nginx.org/HttpLuaModule#tcpsock:setkeepalive)
* timeout - time argument to [settimeout](http://wiki.nginx.org/HttpLuaModule#tcpsock:settimeout)  
* really_close - Call close rather than setkeepalive when calling
close on the client.

### Client Methods ###

#### connect ####
syntax: `local client, err = r:connect()`

Actually connect to riak. 

Returns:

* client - riak client object or _nil_ on error. This client
object can **not** be shared across multipe requests simultaneously, but
can be stored in _ngx.ctx_
* err - error message, if any

#### bucket ####
syntax: `local bucket = client:bucket(name)`

Returns:

* A riak bucket object

Note: this uses _nginx.riak.bucket.new_

#### close ####
syntax: `client:close()`

Close the client. It is no longer usable.  Pass in a _true_ value to
actually call close on the underlying socket, the default is to use
_setkeepalive_.

### Bucket Methods ###

#### new ####
syntax: `local bucket = nginx.riak.bucket.new(client, name)`

Module Function.

Create a new bucket object. client must be an _nginx.riak.client_
object.  In pratice, _client:bucket(name)_ is preferred.

#### new ####
syntax: `local object = bucket:new(key)`
 
Create a new riak value object .

Note: this uses _nginx.riak.object.new_

#### get ####
syntax: `local object, err = bucket:get(key)`

Retrieve an object from the bucket.

Returns:

* object - a riak value object.
* err - error emssage if any. _"not found"_ means the key could not be
  found.
  
#### get_or_new ####
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
syntax: `local object = nginx.riak.object.new(bucket, key)`

Create a new riak value object. This does **not** persist to the
server(s) until _object:store() is called. Generally, _bucket:new(key)_
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
_object:store()_ is called to be successfully stored.

#### get ####
syntax: `local object, err = nginx.riak.object.get(bucket, key)`

Retrive an object. _bucket:get(key)_ is generally preferred.

#### store ####
syntax: `local rc, err = object:store()`

Persist an object to riak.  See the new method for field requirements.

Returns:

* rc - status of store. a _true_ value on success.
* err - error message if any

#### delete ####
syntax: `local rc, err = object:delete()`

Remove an object. see _bucket:delete(key)_ as this is just a wrapper
around it.

## Limitations ##

* This library cannot be used in code contexts like *set_by_lua*, *log_by_lua*, and
*header_filter_by_lua* where the ngx\_lua cosocket API is not available.
* The `nginx.riak.client`, `nginx.riak.bucket`,  and
`nginx.riak.object` object instances  cannot be stored in a Lua variable at the Lua module level,
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
