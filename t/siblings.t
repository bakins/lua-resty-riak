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

=== TEST 1: Test siblings value
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_file '../../examples/siblings.lua';
    }
--- request
GET /t
--- response_body
first
true
2
third
false
--- no_error_log
[error]
