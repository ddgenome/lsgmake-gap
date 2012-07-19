#! /bin/bash
set -e
ruby -w ../lsgmake-gap.rb --dry-run --status ended -j 4 --dependency 123456 \
  -R 'select[type==LINUX64]' --lanes 2,4,7,8 --queue seqmgr-long \
  --path Data/C1-33_Firecrest1.8.26_14-01-2007_mhickenb recursive >test.tmp
ruby -w ../lsgmake-gap.rb --dry-run --queue long \
  --path Data/C1-51,52-102_Firecrest1.3rc4_14-12-2008_mhickenb recursive >>test.tmp
ruby -w ../lsgmake-gap.rb --dry-run --queue long \
  --path Data/C1-159_Firecrest1.3rc4_15-12-2008_mhickenb recursive >>test.tmp
ruby -w ../lsgmake-gap.rb --dry-run --id 32452345 \
  --path Data/C1-159_Firecrest1.3rc4_15-12-2008_mhickenb recursive >>test.tmp
ruby -w ../lsgmake-gap.rb --dry-run --bsub-options '-M 6000000' \
  --path Data/C1-159_Firecrest1.3rc4_15-12-2008_mhickenb recursive >>test.tmp
ruby -w ../lsgmake-gap.rb --dry-run --make 'retry 2 make' \
  --path Data/C1-159_Firecrest1.3rc4_15-12-2008_mhickenb recursive >>test.tmp
ruby -w ../lsgmake-gap.rb --dry-run \
  --path Data/C1-159_Firecrest1.4_15-12-2009_lims recursive >>test.tmp
ruby -w ../lsgmake-gap.rb --dry-run --make 'remake --retry=2' -j 2 \
  --path Data/C1-159_Firecrest1.4_15-12-2009_lims recursive >>test.tmp
ruby -w ../lsgmake-gap.rb --dry-run \
  --path Data/C1-202_Firecrest1.6.0_15-12-2009_lims recursive >>test.tmp
if diff -u test.out test.tmp; then
    echo "no differences found"
    rm test.tmp
    exit 0
fi

exit 1
