#; -*- mode: perl;-*-

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(1);

#plan tests => repeat_each() * blocks();
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

=== TEST 1: put and delete simple string
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local riak = require "nginx.riak"
            local r = riak.new(nil, { timeout = 100 })
            local client = r:connect()
            local b = client:bucket("test")
            local o, err = b:get("doc")
            if not o then
                ngx.say(err)
            end
            ngx.say(o.key)
            o = b:new("1")
            o.value = "test"
            o.content_type = "text/plain"
            local rc, err = o:store()
            ngx.say(rc)
            ngx.say(err)
            client:close()
        ';
    }
--- request
GET /t
--- response_body
doc
true
nil
--- no_error_log
[error]
