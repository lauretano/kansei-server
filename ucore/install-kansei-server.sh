#!/bin/sh

set -ouex pipefail

KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E %fedora)"

#### PREPARE
# enable testing repos if not enabled on testing stream
if [[ "testing" == "${COREOS_VERSION}" ]]; then
for REPO in $(ls /etc/yum.repos.d/fedora-updates-testing.repo); do
  if [[ "$(grep enabled=1 ${REPO} > /dev/null; echo $?)" == "1" ]]; then
    echo "enabling $REPO" &&
    sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' ${REPO}
  fi
done
fi

# add the ucore copr repo
curl -L https://copr.fedorainfracloud.org/coprs/ublue-os/ucore/repo/fedora/ublue-os-ucore-fedora.repo -o /etc/yum.repos.d/ublue-os-ucore-fedora.repo

# add the copr we use for topgrade because this is a home server and i like the orchestration
curl -L https://copr.fedorainfracloud.org/coprs/shdwchn10/AllTheTools/repo/fedora-{RELEASE}/shdwchn10-AllTheTools-fedora-{RELEASE}.repo
# always disable cisco-open264 repo
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo

#### INSTALL
# inspect to see what RPMS we copied in
find /tmp/rpms/

rpm-ostree install /tmp/rpms/ublue-os-ucore-addons-*.rpm

## CONDITIONAL: install ZFS (and sanoid deps)
if [[ "-zfs" == "${ZFS_TAG}" ]]; then
    rpm-ostree install /tmp/rpms/zfs/*.rpm \
      pv
    # for some reason depmod ran automatically with zfs 2.1 but not with 2.2
    depmod -A ${KERNEL}
fi

## CONDITIONAL: install NVIDIA
if [[ "-nvidia" == "${NVIDIA_TAG}" ]]; then
    # repo for nvidia rpms
    curl -L https://negativo17.org/repos/fedora-nvidia.repo -o /etc/yum.repos.d/fedora-nvidia.repo

    curl -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo -o   /etc/yum.repos.d/nvidia-container-toolkit.repo

    rpm-ostree install /tmp/rpms/nvidia/ublue-os-ucore-nvidia-*.rpm
    sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/nvidia-container-toolkit.repo

    rpm-ostree install \
        /tmp/rpms/nvidia/kmod-nvidia-*.rpm \
        nvidia-driver-cuda \
        nvidia-container-toolkit \
        nvidia-docker2
fi

## CONDITIONAL: install DOCKER-CE
if [[ "-dockerce" == "${DOCKERCE_TAG}" ]]; then
  curl --output-dir "/etc/yum.repos.d" --remote-name https://download.docker.com/linux/fedora/docker-ce.repo
  rpm-ostree override remove moby-engine containerd runc docker-cli --install docker-ce
fi


## ALWAYS: install regular packages

# add tailscale repo
curl -L https://pkgs.tailscale.com/stable/fedora/tailscale.repo -o /etc/yum.repos.d/tailscale.repo

# install packages.json stuffs
export IMAGE_NAME=kansei-server
/tmp/packages.sh

# tweak os-release
sed -i '/^PRETTY_NAME/s/"$/ (Fedora CoreOS Kansei)"/' /usr/lib/os-release
