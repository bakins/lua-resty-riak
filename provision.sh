#!/bin/bash
set -e

# I was goign to do puppet or chef, but shell wound up being simpler...

if [ ! -x /usr/local/sbin/nginx ]; then
    apt-get install --yes build-essential wget libpcre3-dev
    cd /tmp
    VERSION=1.2.6.6
    wget --timestamping --quiet http://openresty.org/download/ngx_openresty-$VERSION.tar.gz
    tar -zxvf ngx_openresty-$VERSION.tar.gz
    cd ngx_openresty-$VERSION
    ./configure --with-luajit --prefix=/usr/local --sbin-path=/usr/local/sbin/nginx
    make
    make install
fi

if [ ! -r /etc/apt/sources.list.d/basho.list ]; then
    apt-get install --yes curl
    curl http://apt.basho.com/gpg/basho.apt.key | apt-key add -
    echo deb http://apt.basho.com $(lsb_release -sc) main > /etc/apt/sources.list.d/basho.list
    apt-get update
fi

if [ ! -x /etc/init.d/riak ]; then 
    apt-get install riak
fi

echo "ulimit -n 16384" > /etc/default/riak
/etc/init.d/riak status || /etc/init.d/riak start

apt-get install --yes luarocks git-core cpanminus

luarocks install "https://raw.github.com/Neopallium/lua-pb/master/lua-pb-scm-0.rockspec"
luarocks install lpack

cpanm install Test::Nginx

cd /vagrant
prove
