DRBD_VER ?= 9.0.32-1 # another tested value is: 9.1.11
DRBD_UTILS_VER ?= 9.12.1 # another tested value is: 9.21.4

# Pick a commit according to date from: https://github.com/LINBIT/drbd-headers/commits/master
# For utils 9.21.4: fc45d779096ae5943ea3f56934a1f9b48ffb8e41
DRBD_HEADERS_SHA ?= c757cf357edef67751b8f45a6ea894d287180087 # for utils 9.12.1

KVER := $(shell uname -r)
DIST ?= rhel7
ENTRY ?= /pkgs/entrypoint.adapter.sh
IMG ?= shipper rhel7 rhel8 rhel9 bionic focal jammy
REG ?= daocloud.io/daocloud # Test Registry

drbd9:
	 cd docker-drbd9 && \
	 ./build.sh $(DRBD_VER) rhel7 rhel8 rhel9 bionic focal jammy

compiler-centos7:
	cd docker-shipper && \
	docker build . -f Dockerfile.compiler.centos7 \
		--build-arg HTTP_PROXY=${http_proxy} \
		--build-arg HTTPS_PROXY=${https_proxy} \
		--build-arg FTP_PROXY=${ftp_proxy} \
		--build-arg DRBD_VER=$(DRBD_VER) \
		-t drbd9-compiler-centos7:v$(DRBD_VER)

compiler-centos8:
	cd docker-shipper && \
	docker build . -f Dockerfile.compiler.centos8 \
		--build-arg HTTP_PROXY=${http_proxy} \
		--build-arg HTTPS_PROXY=${https_proxy} \
		--build-arg FTP_PROXY=${ftp_proxy} \
		--build-arg DRBD_VER=$(DRBD_VER) \
		-t drbd9-compiler-centos8:v$(DRBD_VER)

shipper:
	cd docker-shipper && \
	docker build . -f Dockerfile.shipper \
		--build-arg HTTP_PROXY=${http_proxy} \
		--build-arg HTTPS_PROXY=${https_proxy} \
		--build-arg FTP_PROXY=${ftp_proxy} \
		--build-arg DRBD_VER=$(DRBD_VER) \
		--build-arg DRBD_UTILS_VER=$(DRBD_UTILS_VER) \
		--build-arg DRBD_HEADERS_SHA=$(DRBD_HEADERS_SHA) \
		-t drbd9-shipper:v$(DRBD_VER)

cleanup:
	docker volume rm pkgs || true
	rmmod drbd_transport_tcp || true
	rmmod drbd || true
	rm -vf /etc/modules-load.d/drbd.conf
	rm -vfr /lib/modules/$(KVER)/extra/drbd/
	rm -vfr /lib/modules/${KVER}/updates/dkms/drbd/
	depmod -a
	rm -vf /usr/local/bin/drbd*

test-docker:
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
	   -v /usr/local/bin:/usr-local-bin:rw \
	   -v /etc/modules-load.d:/etc/modules-load.d:rw \
	   -e LB_DROP=yes \
	   -it --entrypoint $(ENTRY) \
	   drbd9-$(DIST):v$(DRBD_VER)

test:
	helm install drbd-adapter helm/drbd-adapter \
		-n hwameistor --create-namespace \
		-f helm/drbd-adapter/values.yaml \
		--set imagePullPolicy=Always \
		--set registry=daocloud.io/daocloud

push:
	for i in $(IMG) ; do \
		for j in $(REG); do \
			docker tag drbd9-$$i:v$(DRBD_VER) $$j/drbd9-$$i:v$(DRBD_VER); \
			docker push $$j/drbd9-$$i:v$(DRBD_VER); \
		done \
	done

all: drbd9 compiler-centos7 compiler-centos8 shipper push