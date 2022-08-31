DRBD_VER := 9.1.8
DRBD_UTILS_VER := 9.21.4
KVER := $(shell uname -r)
DIST ?= rhel7
ENTRY ?= /pkgs/entrypoint.adapter.sh

drbd9:
	 cd drbd9-docker && \
	./build.sh $(DRBD_VER)

compiler-centos7:
	docker build . -f Dockerfile.compiler.centos7 \
		--build-arg HTTP_PROXY=${http_proxy} \
		--build-arg HTTPS_PROXY=${https_proxy} \
		--build-arg FTP_PROXY=${ftp_proxy} \
		--build-arg DRBD_VER=$(DRBD_VER) \
		-t drbd9-compiler-centos7:v$(DRBD_VER)

compiler-centos8:
	docker build . -f Dockerfile.compiler.centos8 \
		--build-arg HTTP_PROXY=${http_proxy} \
		--build-arg HTTPS_PROXY=${https_proxy} \
		--build-arg FTP_PROXY=${ftp_proxy} \
		--build-arg DRBD_VER=$(DRBD_VER) \
		-t drbd9-compiler-centos8:v$(DRBD_VER)

shipper:
	docker build . -f Dockerfile.shipper \
		--build-arg HTTP_PROXY=${http_proxy} \
		--build-arg HTTPS_PROXY=${https_proxy} \
		--build-arg FTP_PROXY=${ftp_proxy} \
		--build-arg DRBD_VER=$(DRBD_VER) \
		--build-arg DRBD_UTILS_VER=$(DRBD_UTILS_VER) \
		-t drbd9-shipper:v$(DRBD_VER)

all: drbd9 compiler-centos7 compiler-centos8 shipper

cleanup:
	docker volume rm pkgs || true
	rmmod drbd_transport_tcp || true
	rmmod drbd || true
	rm -vf /etc/modules-load.d/drbd.conf
	rm -vfr /lib/modules/$(KVER)/extra/drbd/
	depmod -a
	rm -vf /usr/local/bin/drbd*

test:
	docker volume rm pkgs || true
	docker run --rm \
	    -v pkgs:/pkgs \
		drbd9-shipper:v$(DRBD_VER)
	docker run --rm \
		-v pkgs:/pkgs \
	   --privileged \
	   -v /etc/os-release:/etc/host-release:ro \
	   -v /etc/centos-release:/etc/centos-release:ro \
	   -v /usr/src:/usr/src:ro \
	   -v /lib/modules:/lib/modules:rw \
	   -v /usr/local/bin:/usr/local/bin:rw \
	   -v /etc/modules-load.d:/etc/modules-load.d:rw \
	   -e LB_DROP=yes \
	   -it --entrypoint $(ENTRY) \
	   drbd9-$(DIST):v$(DRBD_VER)

push:
	for i in shipper rhel7 rhel8 bionic focal jammy; do \
		for j in ghcr.io/alexzhc ghcr.io/hwameistor daocloud.io/daocloud; do \
			docker tag drbd9-$$i:v$(DRBD_VER) $$j/drbd9-$$i:v$(DRBD_VER); \
			docker push $$j/drbd9-$$i:v$(DRBD_VER); \
		done \
	done
