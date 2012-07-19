#! /bin/bash
# retry a program until it succeeds
# Usage: retry N COMMAND ARGS
pkg='retry'
version='0.2'

# get number of retries
if [ "$1" -gt 0 ]; then
    tries="$1"
else
    tries=2
    echo "$pkg: invalid number of tries, using $tries"
fi
shift

# loop through the tries
for (( i = 0 ; i < tries ; ++i )) ; do
    echo "$pkg: attempt $i"
    # run the program
    "$@"
    status=$?
    # exit loop if successfully completed
    if [ $status -eq 0 ]; then
        break
    fi
    # wait a bit
    sleep 1
done

exit $status
