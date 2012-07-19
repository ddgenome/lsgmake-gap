#! /bin/bash
# retry a make until it succeeds, only using parallelization on the first attempt
pkg='remake'
version='0.2'

# defaults
retry=1
jobs=1
cmd=
# loop through positional parameters
prev_arg=
optarg=
for arg
  do
  if test -n "$prev_arg"; then
      eval "$prev_arg=\$arg"
      prev_arg=
      continue
  fi

  case "$arg" in
      -*=*) optarg=`echo "$arg" | sed 's/[-_a-zA-Z0-9]*=//'` ;;
      *) optarg= ;;
  esac

  case "$arg" in
      -h | --help | --hel | --he | --h)
          cat <<EOF
Usage: $pkg [OPTIONS]... [LOGIN]
If an argument to a long option is mandatory, it is also mandatory for
the corresponding short option; the same is true for optional arguments.

Options:
  -h,--help      print this message and exit
  -j,--jobs=N    specifies the number of jobs, default 1
  -r,--retry=N   number of times to retry a failed make, default 1
  -v,--version   print version number and exit

This script wraps around make and retries make if is fails.  Multiple
jobs are only attempted on the first make.

EOF
          exit 0;;

      --version | --versio | --versi | --vers | --ver | --ve)
          echo "$pkg $version"
          exit 0;;

      -j | --jobs | --job | --jo | --j)
          prev_arg=jobs
          ;;

      --jobs=* | --job=* | --jo=* | --j=*)
          jobs="$optarg"
          ;;

      -r | --retry | --retr | --ret | --re | --r)
          prev_arg=retry
          ;;

      --retry=* | --retr=* | --ret=* | --re=* | --r=*)
          retry="$optarg"
          ;;

      *)
          # use unrecognized arguments as make arguments
          cmd="$cmd $arg"
          ;;
  esac
done

# check number of retries
if [ "$retry" -gt 0 ]; then
    :
else
    retry=1
    echo "$pkg: invalid number of tries, using $retry"
fi

# check number of jobs
if [ "$jobs" -gt 0 ]; then
    :
else
    jobs=1
    echo "$pkg: invalid number of jobs, using $jobs"
fi

# loop through the tries
for (( i = 0 ; i < retry ; ++i )) ; do
    echo "[`date`] $pkg: attempt $i"
    make=make
    if [ $i = 0 ]; then
        make="$make -j $jobs"
    fi

    # run the program
    echo "[`date`] $pkg: $make $cmd"
    $make $cmd
    status=$?
    echo "[`date`] $pkg: \$?: $status for $make $cmd"
    # exit loop if successfully completed
    if [ $status -eq 0 ]; then
        break
    fi
    # wait a bit
    sleep 1
done

echo "[`date`] $pkg: exiting with status $status"
exit $status
