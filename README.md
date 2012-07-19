lsgmake-gap
===========

lsgmake-gap is a utility to aid in the parallelization of the Illumina
Genome Analyzer Pipeline on Platform LSF clusters.

lsgmake-gap is distributed under the GNU General Public License
version 3.  See the file COPYING for details.

See the NEWS files for changes from the previous version.

Installation
============

To install it, just put it in your path.  For example:

    $ sudo install lsgmake-gap.rb /usr/local/bin/lsgmake-gap

If you wish to install retry, a script that automatically retries
failed commands, run:

    $ sudo install retry.sh /usr/local/bin/retry

To use retry, use the --make option for lsgmake-gap:

    $ lsgmake-gap --make "retry 2 make" ...

Documentation
=============

You can find the documentation in HTML format in the doc directory.
You can regenerate the documentation with the following command:

    $ rdoc --op doc lsgmake-gap.rb
