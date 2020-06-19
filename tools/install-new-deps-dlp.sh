#!/bin/sh

# This script is used for CI testing.
# Used to install new dependencies.
# If there are new dependencies, they won't be installed in the docker
# container yet, so we just install all deps again.

set -ex

DLP=https://download.opensuse.org/repositories/devel:/languages:/perl/openSUSE_Leap_15.1
OLDDEPS=/tmp/deps.txt
NEWDEPS=/tmp/new-deps.txt
DIFFDEPS=/tmp/diff-deps.txt

source ./tools/tools.sh

listdeps > $OLDDEPS

PERLDEPS=($(listdeps_perl))
echo "${PERLDEPS[@]}"
sudo zypper -n addrepo $DLP dlp || true
sudo zypper -n --gpg-auto-import-keys --no-gpg-checks refresh

sudo zypper install --from dlp -y ${PERLDEPS[@]}

listdeps > $NEWDEPS

echo "Checking updated packages"
if diff -u999 $OLDDEPS $NEWDEPS > $DIFFDEPS; then
    echo "NO DIFF"
else
    echo "=============== DIFF"
    cat $DIFFDEPS
    echo "=============== DIF END"
fi

