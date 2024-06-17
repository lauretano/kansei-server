#!/bin/sh

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

# install packages direct from github
/tmp/github-release-install.sh trapexit/mergerfs fc${RELEASE}.x86_64

# add the coreos pool repo for package versions which can't be found elswehere
curl -L https://raw.githubusercontent.com/coreos/fedora-coreos-config/testing-devel/fedora-coreos-pool.repo -o /etc/yum.repos.d/fedora-coreos-pool.repo

# install packages.json stuffs
export IMAGE_NAME=kansei-server-plus
/tmp/packages.sh

# remove coreos pool repo
rm -f /etc/yum.repos.d/fedora-coreos-pool.repo

# tweak os-release
sed -i '/^PRETTY_NAME/s/(Kansei Server.*$/(Kansei Server Plus)"/' /usr/lib/os-release
