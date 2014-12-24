#!/bin/sh
shift  # get rid of the '-c' supplied by make.

/usr/bin/time -o bench.txt -a -f "[%E] : $*" sh -c "$*"
