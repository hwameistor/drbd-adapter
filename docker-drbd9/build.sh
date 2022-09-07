#!/bin/bash -x

DRBD_VER=${1:-9.0.32-1}

[ -z "$DRBD_VER" ] && echo "Need a DRBD version !" && exit 1

sed -i "s/^ENV DRBD_VERSION.*/ENV DRBD_VERSION ${DRBD_VER}/" Dockerfile.* 

[ -f ./drbd.tar.gz ] || wget https://pkg.linbit.com/downloads/drbd/"$([[ $DRBD_VER =~ ^9.0 ]] && echo 9.0 || echo 9 )"/drbd-${DRBD_VER}.tar.gz -O ./drbd.tar.gz

for i in rhel7 rhel8 bionic focal jammy; do
    df="Dockerfile.${i}"
    [ -f $df ] && \
    docker build . -f "$df"\
        --build-arg HTTP_PROXY=${http_proxy} \
        --build-arg HTTPS_PROXY=${https_proxy} \
        --build-arg FTP_PROXY=${ftp_proxy} \
        -t "drbd9-${i##*.}:v${DRBD_VER}"
done
