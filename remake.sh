#! /bin/bash
# retry a make until it succeeds, only using parallelization on the first attempt
# Usage: remake N J MAKE_ARGS
pkg='remake'
version='0.1'

# get number of retries
if [ "$1" -gt 0 ]; then
    tries="$1"
else
    tries=2
    echo "$pkg: invalid number of tries, using $tries"
fi
shift

# get number of jobs
if [ "$1" -gt 0 ]; then
    jobs="$1"
else
    jobs=1
    echo "$pkg: invalid number of jobs, using $jobs"
fi
shift

# loop through the tries
for (( i = 0 ; i < tries ; ++i )) ; do
    echo "$pkg: attempt $i"
    make=make
    if [ $i = 0 ]; then
        make="$make -j $jobs"
    fi

    # run the program
    $make "$@"
    status=$?
    # exit loop if successfully completed
    if [ $status -eq 0 ]; then
        break
    fi
    # wait a bit
    sleep 1
done

exit $status
