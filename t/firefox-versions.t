#!/bin/sh
echo "1..5"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/firefox-versions.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.latest | not | not'
test 2 '.releases["0.10"] | not | not'
test 3 '.releases["21.0b1"] | not | not'
test 4 '.releases["40.0"] | not | not'
test 5 '.releases["43.0.1"] | not | not'

## Per CC0 <https://creativecommons.org/publicdomain/zero/1.0/>, to
## the extent possible under law, the author of this file has waived
## all copyright and related or neighboring rights to the file.
