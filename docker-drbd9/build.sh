#!/bin/bash -x

DRBD_VER=${1:-9.0.32-1}
ARCH=${2:-linux/amd64}
REG=${3:-daocloud.io/daocloud}

[ -z "$DRBD_VER" ] && echo "Need a DRBD version !" && exit 1

if ! tar -zxf drbd-${DRBD_VER}.tar.gz  --to-stdout > /dev/null; then
    rm -vf drbd-${DRBD_VER}.tar.gz
    wget --no-check-certificate https://pkg.linbit.com/downloads/drbd/"$([[ $DRBD_VER =~ ^9.0 ]] && echo 9.0 || echo 9 )"/drbd-${DRBD_VER}.tar.gz
fi 

rm -vf drbd.tar.gz
cp -vf drbd-${DRBD_VER}.tar.gz drbd.tar.gz

echo $ARCH | sed "s#,# #g"

shift 3
#--progress auto  --progress plain  --progress tty
for i in $@; do
    df="Dockerfile.${i}"
    [ -f "$df" ] || continue
    for a in ${ARCH//,/ }; do
        sed "s/^ENV DRBD_VERSION.*/ENV DRBD_VERSION ${DRBD_VER}/" "$df" | \
        docker build . -f - \
            --platform $a \
            --progress auto \
            -t ${REG}/drbd9-${i##*.}:v${DRBD_VER}_${a/\//-} \
        || exit 1
    done
done
