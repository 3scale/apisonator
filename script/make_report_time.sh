#!/bin/sh
shift  # get rid of the '-c' supplied by make.

\time -o bench.txt -a -f "[%E] : $*" -- sh -c "$*"
