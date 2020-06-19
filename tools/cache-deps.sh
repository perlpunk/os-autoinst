#!/bin/sh

if [[ -z "$CACHEDIR" ]]; then
    echo "CACHEDIR not set" >&2
    exit 1
fi

set -ex
DIFFDEPS=/tmp/diff-deps.txt

MD5="$(md5sum $DIFFDEPS)"

mkdir -p $CACHEDIR

resultfile="$CACHEDIR/$MD5.result"
if [[ -e "$resultfile" ]]; then
    result="$(cat $resultfile)"
    if [[ $result == 1 ]]; then
        echo "$resultfile exists and was successful"
        exit
    fi
fi

cp $DIFFDEPS "$CACHEDIR/$MD5.diff"
result=0
echo $result > "$resultfile"
