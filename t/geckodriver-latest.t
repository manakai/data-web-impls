#!/bin/sh
echo "1..1"
basedir=`dirname $0`/..

test() {
  (grep -P '\Av[0-9](?:[.][0-9]+)*\z' $2 && echo "ok $1") || echo "not ok $1"
}

test 1 $basedir/data/geckodriver-latest.txt

## Per CC0 <https://creativecommons.org/publicdomain/zero/1.0/>, to
## the extent possible under law, the author of this file has waived
## all copyright and related or neighboring rights to the file.
