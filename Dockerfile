FROM centos:7 AS centos7-compiler

RUN yum group install -y 'Development Tools'
RUN yum install -y epel-release wget && \
    yum install -y python-setuptools

RUN wget https://github.com/LINBIT/python-lbdist/archive/master.tar.gz && \
    tar xvf master.tar.gz && \
    cd python-lbdist-master && \
    python setup.py install

COPY kernel-devels.centos7 . 

RUN cat ./kernel-devels.centos7 | xargs -tI % wget % --no-check-certificate

RUN yum localinstall -y ./*.rpm

ARG DRBD_VER=9.1.8

RUN wget --no-check-certificate https://pkg.linbit.com//downloads/drbd/9/drbd-${DRBD_VER}.tar.gz && \
    tar -zxf drbd-${DRBD_VER}.tar.gz

RUN cd drbd-${DRBD_VER} && \ 
    ls -1 /usr/src/kernels | grep -v debug | xargs -tI % make kmp-rpm KDIR=/usr/src/kernels/%

ARG DRBD_VER=9.1.8
FROM quay.io/piraeusdatastore/drbd9-focal:v${DRBD_VER}


