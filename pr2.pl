#!/usr/bin/perl
#
# Simple wrapper to `pr(1)' to help in displaying columns a tad nicer.
# - it works out the screen width
# - by default it wraps and displays text in 2 columns
#
# By Kordian W. <code [at] kordy.com>, April 2001.
#

use strict;
use warnings;

# Default number of columns to display
my $columns = 2;

###################################################################

# Work out the current screen width
(my $screen_width = `stty size </dev/tty`) =~ s/.*\s(\d+).*/$1/s
  or die "$0: `stty size' failed: $!\n";

# How many columns to display?
if (@ARGV)
{
  die "$0: a wrapper to pr(1), takes no of columns to display as parameter.\n" unless $ARGV[0] =~ /^-?\d$/;
  $columns = abs(shift);
}

# The actual work
open (OUT, "| pr -$columns -Tw $screen_width")
  or die qq/$0: Can't open output to "| pr -$columns -Tw $screen_width": $!\n/;
print OUT while (<>);
close OUT;

# EOF
