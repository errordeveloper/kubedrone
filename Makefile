# Copyright 2016 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

KUBE_VERSION ?= 1.4.0-beta.8

RELEASE_URL_PREFIX := https://storage.googleapis.com/kubernetes-release/release

LOCAL_BUILD_OUTPUT := $(GOPATH)/src/k8s.io/kubernetes/_output/local/bin/linux/amd64
LOCAL_BUILD_VERSION := $(shell git --git-dir $(GOPATH)/src/k8s.io/kubernetes/.git describe | sed 's/^v\(.*\)/\1/')

PACKAGE_REV_KUBELET := 0
DIRNAME_KUBELET = kubelet-$(ARCH)-$(KUBE_VERSION)-$(PACKAGE_REV_KUBELET)

PACKAGE_REV_KUBECTL := 0
DIRNAME_KUBECTL = kubectl-$(ARCH)-$(KUBE_VERSION)-$(PACKAGE_REV_KUBECTL)

PACKAGE_REV_KUBEADM := 0
DIRNAME_KUBEADM = kubeadm-$(ARCH)-$(KUBE_VERSION)-$(PACKAGE_REV_KUBEADM)

GIT_REV_KUBECNI := 07a8a28637e97b22eb8dfe710eeae1344f69d16e
PACKAGE_REV_KUBECNI := 0
PACKAGE_VER_KUBECNI := 0.3.0.1-07a8a2
DIRNAME_KUBECNI = kubecni-$(ARCH)-$(PACKAGE_VER_KUBECNI)-$(PACKAGE_REV_KUBECNI)

CURL := curl --location --silent --fail

packages-from-release-output:
	for component in kubectl kubelet kubeadm ; do \
	  for arch in amd64 arm64 ; do \
	    $(MAKE) $$component-build ARCH="$$arch" \
	  ; done \
	; done

packages-from-local-build-output:
	for component in kubectl kubelet kubeadm ; do \
	  $(MAKE) $$component-setup ARCH="amd64" KUBE_VERSION="$(LOCAL_BUILD_VERSION)" \
	; done
	$(MAKE) copy-local-build-artefacts ARCH="amd64" KUBE_VERSION="$(LOCAL_BUILD_VERSION)"
	for component in kubectl kubelet kubeadm kubecni ; do \
	  $(MAKE) $$component-build ARCH="amd64" KUBE_VERSION="$(LOCAL_BUILD_VERSION)" \
	; done

copy-deb-packages:
	@install -v -m 0755 -d "images/src/deb"
	@find build/pkg/ -name '*.deb' | xargs -n 1 install -v -m 644 -t "images/src/deb"


#copy-rpm-packages:
#	@install -v -m 0755 -d "images/src/rpm"
#	@find build/pkg/ -name '*.rpm' | xargs -n 1 install -v -m 644 -t "images/src/rpm"

copy-binaries-for-docker-images:
	for component in hyperkube ; do \
	  cp $(LOCAL_BUILD_OUTPUT)/$$component images/kube-cluster-components/$$component \
	; done

copy-local-build-artefacts:
	cp $(LOCAL_BUILD_OUTPUT)/kubectl build/src/$(DIRNAME_KUBECTL)/usr/bin/kubectl
	cp $(LOCAL_BUILD_OUTPUT)/kubelet build/src/$(DIRNAME_KUBELET)/usr/sbin/kubelet
	cp $(LOCAL_BUILD_OUTPUT)/kubeadm build/src/$(DIRNAME_KUBEADM)/usr/sbin/kubeadm

kubectl-build:
	$(MAKE) kubectl-setup
	$(MAKE) build/src/$(DIRNAME_KUBECTL)/usr/bin/kubectl
	$(MAKE) build-packages \
	  NAME="kubectl" \
	  DESC="kubectl: The Kubernetes command line tool for interacting with the Kubernetes API" \
	  ARCH="$(ARCH)" \
	  ITER="$(PACKAGE_REV_KUBECTL)" \
	  DIRNAME="$(DIRNAME_KUBECTL)" \
	  SRCDIRS="usr/bin"

kubelet-build:
	$(MAKE) kubelet-setup
	$(MAKE) build/src/$(DIRNAME_KUBELET)/usr/sbin/kubelet
	$(MAKE) build-packages \
	  NAME="kubelet" \
	  DESC="kubelet: The Kubernetes Node Agent" \
	  ARCH="$(ARCH)" \
	  ITER="$(PACKAGE_REV_KUBELET)" \
	  DIRNAME="$(DIRNAME_KUBELET)" \
	  SRCDIRS="usr/sbin lib/systemd"

kubeadm-build:
	$(MAKE) kubeadm-setup
	$(MAKE) build/src/$(DIRNAME_KUBEADM)/usr/sbin/kubeadm
	$(MAKE) build-packages \
	  NAME="kubeadm" \
	  DESC="kubeadm: The Kubernetes commadn line tool for creating and managing cluster lifecycle" \
	  ARCH="$(ARCH)" \
	  ITER="$(PACKAGE_REV_KUBEADM)" \
	  DIRNAME="$(DIRNAME_KUBEADM)" \
	  SRCDIRS="usr/sbin etc/systemd"

kubecni-build:
	$(MAKE) kubecni-setup
	$(MAKE) kubecni-fetch
	$(MAKE) build-packages \
	  NAME="kubecni" \
	  DESC="kubecni: Container Networking Interface plugins for Kubernetes" \
	  KUBE_VERSION="$(PACKAGE_VER_KUBECNI)" \
	  ARCH="$(ARCH)" \
	  ITER="$(PACKAGE_REV_KUBECNI)" \
	  DIRNAME="$(DIRNAME_KUBECNI)" \
	  SRCDIRS="usr/lib"

kubectl-setup:
	@install -v -m 755 -d "build/src/$(DIRNAME_KUBECTL)/usr/bin"

kubelet-setup:
	@install -v -m 755 -d "build/src/$(DIRNAME_KUBELET)/usr/sbin"
	@install -v -m 755 -d "build/src/$(DIRNAME_KUBELET)/lib/systemd/system"
	@install -v -m 755 -t "build/src/$(DIRNAME_KUBELET)/lib/systemd/system" "share/kubelet/lib/systemd/system/kubelet.service"

kubeadm-setup:
	@install -v -m 755 -d "build/src/$(DIRNAME_KUBEADM)/usr/sbin"
	@install -v -m 755 -d "build/src/$(DIRNAME_KUBEADM)/etc/systemd/system/kubelet.service.d"
	@install -v -m 755 -t "build/src/$(DIRNAME_KUBEADM)/etc/systemd/system/kubelet.service.d" "share/kubeadm/etc/systemd/system/kubelet.service.d/10-kubeadm.conf"

kubecni-setup:
	@install -v -m 755 -d "build/src/$(DIRNAME_KUBECNI)/usr/lib/kubernetes/cni"

build/src/$(DIRNAME_KUBECTL)/usr/bin/kubectl:
	$(CURL) "$(RELEASE_URL_PREFIX)/v$(KUBE_VERSION)/bin/linux/$(ARCH)/kubectl" --output "$@"

build/src/$(DIRNAME_KUBELET)/usr/sbin/kubelet:
	$(CURL) "$(RELEASE_URL_PREFIX)/v$(KUBE_VERSION)/bin/linux/$(ARCH)/kubelet" --output "$@"

build/src/$(DIRNAME_KUBEADM)/usr/sbin/kubeadm:
	$(CURL) "$(RELEASE_URL_PREFIX)/v$(KUBE_VERSION)/bin/linux/$(ARCH)/kubeadm" --output "$@"

kubecni-fetch:
	$(CURL) "$(RELEASE_URL_PREFIX)/../network-plugins/cni-$(ARCH)-$(GIT_REV_KUBECNI).tar.gz" | tar xz -C build/src/$(DIRNAME_KUBECNI)/usr/lib/kubernetes/cni

build-packages:
	@mkdir -p build/pkg/$(DIRNAME)
	cd build/pkg/$(DIRNAME) ; for t in deb pacman rpm tar ; do fpm \
	  --chdir ../../src/$(DIRNAME) \
	  --input-type dir \
	  --output-type $$t \
	  --name $(NAME) \
	  --version $(KUBE_VERSION) \
	  --iteration $(ITER) \
	  --architecture $(ARCH) \
	  --license Apache-2.0 \
	  --maintainer "Kubernetes Authors <kubernetes-dev@google.com>" \
	  --vendor "Kubernetes Authors <kubernetes-dev@google.com>" \
	  --description "$(DESC)" \
	  --url https://k8s.io/ \
	  --rpm-compression xz \
	  --pacman-compression xz \
	  $(SRCDIRS) \
	; done
