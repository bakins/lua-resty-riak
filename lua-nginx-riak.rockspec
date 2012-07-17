package = "lua-nginx-riak"
version = "0.0.1-1"
source = {
    url = "http://"
}
description = {
   summary = "ngx_lua Riak protocol buffer client",
   homepage = "https://bitbucket.org/vgtf/lua-nginx-riak", -- We don't have one yet
   license = "BSD" -- or whatever you like
}
dependencies = {
    "lua-pb",
    "lpack"
}
build = {
    type = "builtin",
    modules = {
        ["nginx.riak"] = "lib/nginx/riak.lua",
        ["nginx.riak.client"] = "lib/nginx/riak/client.lua",
        ["nginx.riak.bucket"] = "lib/nginx/riak/bucket.lua",
        ["nginx.riak.object"] = "lib/nginx/riak/object.lua",
    }
}

