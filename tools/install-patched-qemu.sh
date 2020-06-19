#!/bin/sh

set -ex

QEMU=http://download.opensuse.org/repositories/devel:/openQA:/ci/openSUSE_Leap_15.1

sudo zypper -n addrepo $QEMU qemu || true
sudo zypper -n --gpg-auto-import-keys --no-gpg-checks refresh
sudo zypper -n in --from qemu qemu qemu-x86 qemu-tools qemu-ipxe qemu-sgabios qemu-seabios
