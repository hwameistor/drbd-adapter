#!/bin/bash -x

# 安装所需软件包
yum install -y build-essential wget flex automake

tar xf /root/drbd-utils.tar.gz

cd /root/drbd-utils/

./autogen.sh

./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc

make tools

find ./user -type f -executable -name 'drbd[a-z]*' -exec mv -v {} /usr/local/bin/ \;