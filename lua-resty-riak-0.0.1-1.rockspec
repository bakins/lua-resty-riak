package = "lua-resty-riak"
version = "0.0.1-1"
source = {
   url = "http://"
}
description = {
   summary = "ngx_lua Riak protocol buffer client",
   homepage = "https://bitbucket.org/vgtf/lua-resty-riak",
   license = "BSD"
}
dependencies = {
             --   "lpack"
}
build = {
   type = "builtin",
   modules = {
      ['resty.riak'] = "lib/resty/riak.lua",
      ['resty.riak.bucket'] = "lib/resty/riak/bucket.lua",
      ['resty.riak.object'] = "lib/resty/riak/object.lua"
   }
}
