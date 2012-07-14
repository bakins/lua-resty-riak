#; -*- mode: perl;-*-

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * blocks();

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
            local r = riak.new()
            local client = r:connect()
            local b = client:bucket("test")
            local o = b:new("1")
            o.value = "test"
            o:store()
            r:close()
        ';
    }
--- request
GET /t
--- response_body
true
true
--- no_error_log
[error]
