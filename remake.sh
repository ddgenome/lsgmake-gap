#! /bin/bash
# retry a make target until it succeeds
# Usage: remake N MAKE_ARGS
pkg=remake
version=0.1

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
    # run make
    make "$@"
    status=$?
    # exit loop if successfully completed
    if [ $status -eq 0 ]; then
        break
   fi
done

exit $status
