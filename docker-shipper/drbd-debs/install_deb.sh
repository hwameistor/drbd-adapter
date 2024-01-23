#!/bin/bash -x

install_cmd="apt install -y /root/drbd.deb"
Y | $install_cmd
apt install -y /root/drbd_utils.deb

