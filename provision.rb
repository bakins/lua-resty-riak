%w[ build-essential wget libpcre3-dev luarocks git-core cpanminus curl ].each do |p|
  package p
end

execute "install basho key" do
  command "curl http://apt.basho.com/gpg/basho.apt.key | apt-key add -"
  action :nothing
  notifies :run, "execute[apt-get update]", :immediately
end

execute "apt-get update" do
   action :nothing
end

file "/etc/apt/sources.list.d/basho.list" do
  content "deb http://apt.basho.com #{node['lsb']['codename']} main\n"
  notifies :run, "execute[install basho key]", :immediately
end

riak_version = "2.0.0"
remote_file "/usr/src/riak_#{riak_version}-1_amd64.deb" do
  source "http://s3.amazonaws.com/downloads.basho.com/riak/2.0/#{riak_version}/ubuntu/precise/riak_#{riak_version}-1_amd64.deb"
  checksum "285d54c66337092e835c587d42bbd6c2e7cfae93071a52902fef0be8053a007a"
end

dpkg_package "riak" do
  version "#{riak_version}-1"
  source "/usr/src/riak_#{riak_version}-1_amd64.deb"
end

file "/etc/default/riak" do
  content "ulimit -n 65536\n"
  notifies :restart, "service[riak]"
end

template "/etc/riak/app.config" do
  source "/vagrant/app.config"
  local true
  notifies :restart, "service[riak]"
end

service "riak" do
  action [ :enable, :start]
end

execute "luarocks install https://raw.github.com/Neopallium/lua-pb/master/lua-pb-scm-0.rockspec" do
  not_if "luarocks show lua-pb"
end

execute "luarocks install lpack" do
  not_if "luarocks show lpack"
end

execute "cpanm install Test::Nginx" do
  not_if "perl -mTest::Nginx -e'1'"
end

openresty_version = "1.7.2.1"

check_nginx_version = "/usr/local/sbin/nginx -v 2>&1 | grep 'openresty/#{openresty_version}'"

remote_file "/home/vagrant/ngx_openresty-#{openresty_version}.tar.gz" do
  source "http://openresty.org/download/ngx_openresty-#{openresty_version}.tar.gz"
  notifies :run, "execute[install openresty]"
  not_if check_nginx_version
end

execute "install openresty" do
  cwd "/home/vagrant"
  command <<EOF
 tar -zxvf ngx_openresty-#{openresty_version}.tar.gz
cd ngx_openresty-#{openresty_version}
./configure --with-luajit --prefix=/usr/local --sbin-path=/usr/local/sbin/nginx
make
make install
EOF
  not_if check_nginx_version
end
