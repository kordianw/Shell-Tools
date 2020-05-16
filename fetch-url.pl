#!/usr/bin/perl
# fetch URL text via WWW::Mechanize

use strict;
use warnings;

# allow script-dir modules to be found, when running from any dir
BEGIN {
  require FindBin;
  my ($path) = $FindBin::RealBin =~ m#^([\w~: \/-]+)$#;
  unshift @INC, $path, "$path/lib", "$path/.." if $path;
}

use lib qw/. ../;

# use the WWW::Mechanize module
use WWWMechanize;

# make sure we can print out UTF8 chars
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

##################################################

die "$0: need URL as param!\n" unless $ARGV[0];
warn "Fetching << $ARGV[0] >> via WWW::Mechanize\n";

# set-up WWW::Mechanize to fetch the URL
my $mech = new WWWMechanize;
$mech->agent_alias('Windows Mozilla');

#
# GET URL
#
$mech->get($ARGV[0]);
my $out = $mech->text();

#
# PRINT
#
print "$out\n";

#EOF
