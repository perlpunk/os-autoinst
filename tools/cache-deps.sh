#!/bin/sh

if [[ -z "$CACHEDIR" ]]; then
    echo "CACHEDIR not set" >&2
    exit 1
fi

set -ex
DIFFDEPS=/tmp/diff-deps.txt

MD5="$(md5sum $DIFFDEPS | cut -f1 -d' ')"

mkdir -p $CACHEDIR

resultfile="$CACHEDIR/$MD5.result"
if [[ -e "$resultfile" ]]; then
    result="$(cat $resultfile)"
    if [[ $result == 0 ]]; then
        echo "$resultfile already exists and was successful" >&2
        exit
    fi
fi

cp $DIFFDEPS "$CACHEDIR/$MD5.diff"
result=1
echo $result > "$resultfile"

result=0
./autogen.sh && make || (result=1 && exit 1)
make check || result=1
make test || result=1

echo $result > "$resultfile"

exit $result
