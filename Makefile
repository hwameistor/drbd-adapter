SHELL := /bin/bash
ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

CHART_VER ?= 0.4.3
DRBD_VER ?= 9.0.32-1# another tested value is: 9.1.11
DRBD_UTILS_VER ?= 9.12.1# another tested value is: 9.21.4

# Pick a commit according to date from: https://github.com/LINBIT/drbd-headers/commits/master
# For utils 9.21.4: fc45d779096ae5943ea3f56934a1f9b48ffb8e41
DRBD_HEADERS_SHA ?= c757cf357edef67751b8f45a6ea894d287180087# for utils 9.12.1

KVER := $(shell uname -r)
DIST ?= rhel7
ENTRY ?= /pkgs/entrypoint.adapter.sh

ARCH ?= linux/amd64,linux/arm64
IMG ?= shipper rhel7 rhel8 rhel9 bionic focal jammy kylin10

# Default test registry
REG ?= daocloud.io/daocloud

update_chart_ver: 
	if sed --version | grep -iw gnu; then \
		sed -i 's/version:.*/version: v$(CHART_VER)/' ./helm/drbd-adapter/Chart.yaml; \
	else \
		sed -i '' 's/version:.*/version: v$(CHART_VER)/' ./helm/drbd-adapter/Chart.yaml; \
	fi 
	grep ^version ./helm/drbd-adapter/Chart.yaml

drbd9:
	 cd docker-drbd9 && \
	 ./build.sh $(DRBD_VER) $(ARCH) $(REG) $(CHART_VER) $(IMG)

compiler-centos7:
	for a in $(shell echo $(ARCH) | tr ',' ' '); do \
		docker build docker-shipper/ -f docker-shipper/Dockerfile.shipper \
			--platform $$a \
			--progress tty \
			--target compiler-centos7 \
			--build-arg DRBD_VER=$(DRBD_VER) \
			-t $(REG)/drbd9-compiler-centos7:v$(DRBD_VER)_$${a/\//-}; \
	done

compiler-centos8:
	for a in $(shell echo $(ARCH) | tr ',' ' '); do \
		docker build docker-shipper/ -f docker-shipper/Dockerfile.shipper \
			--platform $$a \
			--progress tty \
			--target compiler-centos8 \
			--build-arg DRBD_VER=$(DRBD_VER) \
			-t $(REG)/drbd9-compiler-centos8:v$(DRBD_VER)_$${a/\//-}; \
	done

compiler-utils:
	for a in $(shell echo $(ARCH) | tr ',' ' '); do \
		docker build docker-shipper/ -f docker-shipper/Dockerfile.shipper \
			--platform $$a \
			--progress tty \
			--target compiler-utils \
			--build-arg DRBD_VER=$(DRBD_VER) \
			--build-arg DRBD_UTILS_VER=$(DRBD_UTILS_VER) \
			--build-arg DRBD_HEADERS_SHA=$(DRBD_HEADERS_SHA) \
			-t $(REG)/drbd9-compiler-utils:v$(DRBD_VER)_$${a/\//-}; \
	done

shipper: update_chart_ver
	for a in $(shell echo $(ARCH) | tr ',' ' '); do \
		docker build docker-shipper/ -f docker-shipper/Dockerfile.shipper \
			--platform $$a \
			--progress auto \
			--build-arg DRBD_VER=$(DRBD_VER) \
			--build-arg DRBD_UTILS_VER=$(DRBD_UTILS_VER) \
			--build-arg DRBD_HEADERS_SHA=$(DRBD_HEADERS_SHA) \
			-t $(REG)/drbd9-shipper:v$(DRBD_VER)_v$(CHART_VER)_$${a/\//-}; \
	done

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
		drbd9-shipper:v$(DRBD_VER)_v$(CHART_VER)
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
		$(REG)/drbd9-$(DIST):v$(DRBD_VER)

test:
	helm install drbd-adapter helm/drbd-adapter \
		-n hwameistor --create-namespace \
		-f helm/drbd-adapter/values.yaml \
		--set imagePullPolicy=Always \
		--set registry=daocloud.io/daocloud

push:
	set -x; \
	for i in $(IMG); do \
		ver=$(DRBD_VER)_v$(CHART_VER); \
		docker manifest rm $(REG)/drbd9-$$i:v$${ver}; \
			for a in $(shell echo $(ARCH) | tr ',' ' ' ); do \
				docker push $(REG)/drbd9-$$i:v$${ver}_$${a/\//-} || \
				docker push $(REG)/drbd9-$$i:v$${ver}_$${a/\//-}; \
				docker manifest create --amend $(REG)/drbd9-$$i:v$${ver} $(REG)/drbd9-$$i:v$${ver}_$${a/\//-}; \
			done; \
		docker manifest push --purge $(REG)/drbd9-$$i:v$${ver}; \
		docker manifest inspect $(REG)/drbd9-$$i:v$${ver}; \
	done

all: drbd9 shipper push
