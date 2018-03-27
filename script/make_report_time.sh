#!/bin/sh
shift  # get rid of the '-c' supplied by make.

if command time --version > /dev/null 2>&1
then
        \command time -o bench.txt -a -f "[%E] : $*" -- sh -c "$*"
else
        \echo "$*" >> bench.txt
        \command time 3>&2 4>> bench.txt 2>&4 sh -c "$* 2>&3"
fi
