#!/software/bin/perl -T
# ----------------------------------------------------------------------
# Author:        ts6
# Maintainer:    $Author: rmp $
# Created:       2008-04-28
# Last Modified: $Date: 2008-09-09 16:30:14 +0100 (Tue, 09 Sep 2008) $
# Id:            $Id: lsgmake.pl 2988 2008-09-09 15:30:14Z rmp $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/sanger-pipeline/trunk/bin/lsgmake.pl $
#
# ----------------------------------------------------------------------
#
# Submit make jobs for the analysis pipeline to lsf. Parallelise by lanes
# where possible. Be aware of control lane dependencies.

# This is a perl re-implementation of the lsgmake-gap.rb Ruby script
# by David Dooling at Wash U. The needs of the current Sanger
# auto-analysis tool as of pipeline release 1.0 have diverged from
# what lsgmake-gap.rb provides to the extent that a new version,
# maintained locally, is required. That seemed like a perfect
# opportunity to switch it over to perl to match the rest of the
# AA scripts.

# Not all the functionality of lsgmake-gap.rb is reproduced here. This
# script is intended to support automated analyses whose processing is
# the same, with minor variations, for every run.

# ----------------------------------------------------------------------

use strict;
use warnings;
use English qw(-no_match_vars);
use Carp;

use Getopt::Long;
use Cwd;      # for getcwd

sub initialise;
sub process;

our $VERSION = do { my ($r) = q$LastChangedRevision: 2988 $ =~ /(\d+)/mx; $r; };

our $MAKE_EXE = '/software/solexa/bin/make';
our $MEM_REQ = 13800;

# Untainted $PATH

$ENV{'PATH'} = join q[:], qw(/usr/local/lsf/6.2/linux2.6-glibc2.3-x86_64/bin
                             /usr/local/lsf/6.2/linux2.6-glibc2.3-x86_64/etc
                             /software/solexa/bin
                             /software/bin
                             /software/badger/bin
                             /software/noarch/badger/bin
                             /bin
                             /usr/bin
                             /usr/local/bin);


$OUTPUT_AUTOFLUSH = 1;

process;

exit;

# ----------------------------------------------------------------------
sub usage {

  ## no critic

  print STDERR "\n";
  print STDERR "lsgmake.pl: version $VERSION command line parameters:\n";
  print STDERR "\n";
  print STDERR "    --path          firecrest directory where makes are to be run\n";
  print STDERR "    --paired        run is paired-end\n";
  print STDERR "    --control-lane  control lane number (def none)\n";
  print STDERR "    --lanes         comma-separated list of lane numbers to process (def 1,2,3,4,5,6,7,8)\n";
  print STDERR "    --jobs          number of make processes to run (def 1)\n";
  print STDERR "    --test          print commands which would be executed, but don't really do anything\n";
  print STDERR "    --test-make     run makes with -n parameter so they don't do anything\n";
  print STDERR "    --verbose       be verbose\n";
  print STDERR "    --help          output this message and quit\n";
  print STDERR "\n";
  print STDERR "    Include control lane in lane list if you want sequence data for it.\n";
  print STDERR "\n";

  ## use critic

  return;

}

# ----------------------------------------------------------------------
# Submit analysis pipeline jobs under lsf as a series of makes,
# parallelised where possible.

# The processing submitted here produces a calibration table from the
# control lane, and then applies it to the other sample lanes. One
# complication in doing that involves qval files. There is one qval
# file for each read of each tile -- but they are produced in pairs
# from one invocation of extract_quality_predictors. I (reluctantly)
# had to hack GERALD.xml to include the target 'qval_s_<lane>' which
# depends on all the qval files for the lane. (NOTE: as of release
# 1.0, those targets are created by the release version of GERALD).

# qvals are required as input to the calibration table creation, but
# also to the actual calibration step. So I submit qval makes for all
# lanes in parallel, followed by qtable makes, followed by the lane
# makes which do the calibration and sequence generation using qvals
# and qtables as input.

sub process {

  my $opts = initialise;

  my $lane_targets = [ map {"s_$_"} split /,/xm, detaint ($opts->{'lanes'}, qr/([\d,]+)/xm) ];
  my $phasing_targets = [ map {"Phasing/${_}_phasing.xml"} @{$lane_targets} ];
  my $qval_targets    = [ map {"${_}_qvals"} @{$lane_targets} ];

  my $control_targets = [];
  if (exists $opts->{'control-lane'}) {
    my $control_lane = detaint ($opts->{'control-lane'}, qr/(\d+)/xm);
    if (exists $opts->{'paired'}) {
      $control_targets = ["s_${control_lane}_1_qtable.txt s_${control_lane}_2_qtable.txt"];  # 2 targets, 1 make
    } else {
      $control_targets = ["s_${control_lane}_qtable.txt"];
    }
  }

  my ($fq_firecrest, $fq_bustard, $fq_gerald) = get_dirs ($opts->{'path'});
  my $deps = [];

  $deps = bsub ($fq_firecrest, $deps, $opts, ['default_offsets.txt']);
  $deps = bsub ($fq_firecrest, $deps, $opts, $lane_targets);
  $deps = bsub ($fq_firecrest, $deps, $opts, ['all']);

  $deps = bsub ($fq_bustard,   $deps, $opts, $phasing_targets);
  $deps = bsub ($fq_bustard,   $deps, $opts, ['Phasing/phasing.xml']);
  $deps = bsub ($fq_bustard,   $deps, $opts, $lane_targets);
  $deps = bsub ($fq_bustard,   $deps, $opts, ['all']);

  $deps = bsub ($fq_gerald,    $deps, $opts, ['tiles.txt']);
  $deps = bsub ($fq_gerald,    $deps, $opts, $qval_targets);

  if (scalar @{$control_targets} > 0) {
    # Should the qval makes go here? Is no control lane even a valid state of affairs?
    $deps = bsub ($fq_gerald,    $deps, $opts, $control_targets);
  }

  $deps = bsub ($fq_gerald,    $deps, $opts, $lane_targets);
  $deps = bsub ($fq_gerald,    $deps, $opts, ['all']);

  return;

}

# ----------------------------------------------------------------------
sub initialise {

  my %options = (path  => q[.],
                 jobs  => 1,
                 lanes => '1,2,3,4,5,6,7,8',
                 );

  my $rc = GetOptions(\%options,
                      'path:s',
                      'paired',
                      'lanes:s',
                      'control-lane:s',
                      'jobs:i',
                      'test',
                      'test-make',
                      'verbose',
                      'help');

  if (exists $options{'help'}) {
    usage;
    exit;
  }

  if ( ! $rc) {
    print {*STDERR} "\nerror in command line parameters\n" or croak 'print failed';
    usage;
    exit 1;
  }

  $options{'jobs'} = detaint ($options{'jobs'}, qr/(\d+)/xm);

  if ($options{'verbose'}) {
    # include callbacks in croak messages
    $Carp::Verbose = 1;     ## no critic
  }

  return \%options;

}

# ----------------------------------------------------------------------
# Starting in the Firecrest directory specified on the command line,
# return fully qualitied folder names for Firecrest, Bustard and
# Gerald directories.

sub get_dirs {

  my ($firecrest) = @_;

  my $cur_dir = detaint(getcwd(), qr/([\w\/\-\.\,]+)/xm);  # save for later

  my @bustards = glob "$firecrest/Bustard*";
  if (scalar @bustards == 0) {
    croak "no Bustard directory in $firecrest";
  } elsif (scalar @bustards > 1) {
    croak "more than one Bustard directory in $firecrest";
  }
  my $bustard = $bustards[0];

  my @geralds = glob "$bustard/GERALD*";
  if (scalar @geralds == 0) {
    croak "no Gerald directory in $bustard";
  } elsif (scalar @geralds > 1) {
    croak "more than one Gerald directory in $bustard";
  }

  my $gerald = detaint($geralds[0], qr/([\w\-\.\,\/]+)/xm);
  chdir $gerald or croak "cannot cd to Gerald directory $gerald";

  my $fq_gerald = detaint(getcwd(), qr/([\w\/\-\.\,]+)/xm);
  my ($fq_bustard) = $fq_gerald =~ /^(.*)\/[^\/]+$/xm;
  my ($fq_firecrest) = $fq_bustard =~ /^(.*)\/[^\/]+$/xm;

  chdir $cur_dir or croak "could not cd back to $cur_dir";  # go back home

  return ($fq_firecrest, $fq_bustard, $fq_gerald);

}

# ----------------------------------------------------------------------
sub bsub {

  my ($dir, $deps, $opts, $targets) = @_;

  my ($runfolder) = $dir =~ /(\d{6}_IL\d+_\d+)/xm;
  my ($target_dir) = $dir =~ /\/([^\/]+)$/xm;
  $target_dir =~ s/,/-/gxm;                                # bsub doesn't like commas

  my $wait_for = join q[ && ], map {"done($_)"} @{$deps};

  my $jobs = $opts->{'jobs'};
  my $new_deps = [];

  my $cur_dir = detaint(getcwd(), qr/([\w\/\-\.\,]+)/xm);  # save for later

  chdir $dir or croak "could not cd to $dir";

  foreach my $targ (@{$targets}) {

    my ($short_targ) = $targ =~ /([^\/]+)$/xm;             # get rid of Phasing/
    $short_targ =~ s/\s.*//xm;                             # get rid of second target

    my $run_name = "s$runfolder.$target_dir.$short_targ";
    push @{$new_deps}, $run_name;

    my @command = ();
    push @command, "bsub -n $jobs";
    push @command, "-R \"select\[mem>$MEM_REQ\] rusage\[mem=$MEM_REQ\] span[hosts=1]\" -M ${MEM_REQ}000";
    push @command, "-o make-$short_targ-\%J.out";
    push @command, "-J $run_name";
    push @command, "-C 99999999";

    if ($wait_for) {
      push @command, "-w \"$wait_for\"";
    }

    push @command, $MAKE_EXE;

    if (exists $opts->{'test-make'}) {
      push @command, '-n';
    }

    push @command, "-j $jobs $targ";

    my $bsub_command = join q[ ], @command;

    if (exists $opts->{'test'} || exists $opts->{'verbose'}) {
      print {*STDERR} $bsub_command, "\n" or croak 'print failed';
    }

    if ( ! exists $opts->{'test'}) {
      my $rc = system $bsub_command;
      if ($rc) {
        if ( ! exists $opts->{'verbose'}) {         # already printed?
          print {*STDERR} $bsub_command, "\n" or croak 'print failed';
        }
        croak "$run_name bsub command failed: $rc";
      }
    }

  }

  chdir $cur_dir or croak "could not cd back to $cur_dir";  # go back home

  return $new_deps;

}

# ----------------------------------------------------------------------
sub detaint {

  my ($string, $regex) = @_;

  my ($dt) = $string =~ /$regex/xm;

  if ($dt ne $string) {
    croak ("could not detaint $string, got $dt");
  }

  return $dt;

}
