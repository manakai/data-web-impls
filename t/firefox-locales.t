#!/bin/sh
echo "1..4"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/firefox-locales.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.locales["en-US"] | not | not'
test 2 '.locales["en-GB"] | not | not'
test 3 '.locales["ja"] | not | not'
test 4 '.locales["zh-TW"] | not | not'

## Per CC0 <https://creativecommons.org/publicdomain/zero/1.0/>, to
## the extent possible under law, the author of this file has waived
## all copyright and related or neighboring rights to the file.
