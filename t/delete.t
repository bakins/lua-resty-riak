#; -*- mode: perl;-*-

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(2);
plan tests => repeat_each() * blocks() * 3;

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_RIAK_PORT} ||= 8087;

no_long_string();

run_tests();

__DATA__

=== TEST 1: delete
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            require "luarocks.loader"
            local riak = require "resty.riak"
            local r = riak.new()
            local client = r:connect("127.0.0.1", 8087)
            local b = client:bucket("test")
            local o = b:new("1")
            o.value = "test"
            o.content_type = "text/plain"
            local rc, err = o:store()  
            o:delete() 
            local rc, err = b:delete("1")
            ngx.say(rc)
            client:close()
        ';
    }
--- request
GET /t
--- response_body
true
--- no_error_log
[error]
