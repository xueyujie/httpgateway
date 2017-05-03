############################################################
# 创建openresty环境的dockerfile
# Based on Centos 7
############################################################
# Set the base image to Ubuntu
FROM daocloud.io/centos:7
# File Author / Maintainer
MAINTAINER lvyalin lvyalin.lv.yl@gmail.com

RUN yum install -y ftp vim wget crontabs gcc make git

RUN yum install -y readline-devel pcre-devel openssl-devel gcc perl-Digest-MD5

# install openresty
RUN wget https://openresty.org/download/openresty-1.11.2.3.tar.gz && \
tar -xzvf openresty-1.11.2.3.tar.gz && \
cd openresty-1.11.2.3 && \
./configure && \
make && \
make install && \
ln -s /usr/local/openresty/nginx/conf /etc/nginx && \
ln -s -T /usr/local/openresty/bin/opm /usr/bin/opm && \
ln -s -T /usr/local/openresty/bin/resty /usr/bin/resty

# install plugins
opm get openresty/lua-resty-limit-traffic && \
opm get hamishforbes/lua-resty-iputils && \
opm get firesnow/lua-resty-location-match && \
opm get firesnow/lua-resty-checkups