#!/usr/bin/perl -w
# Quick and user-friendly filter to netstat(8) which makes the output more relevant + tidied.
# - works on Linux/Unix & Cygwin
#
# * By Kordian Witek <code [at] kordy.com>, Jan 2002
#
use strict;
use warnings;

use Socket;
use Getopt::Std;

use vars qw($opt_a);

(my $prog = $0) =~ s#.*/##;		# could use File::Basename here.
&getopts("a")
  or die "Usage: $prog [-a]\n";		# -a to list all types of connections.

#############
open(NS, "netstat -n |")
  or die qq|$prog: can not run "netstat -n": $!\n|;

my %seen;
while(<NS>)
{
  next unless /(ESTABLISHED|_WAIT|CLOSED|SYN_|_ACK)/;
  next unless /ESTABLISHED/ or $opt_a;		# confusing "if" statement :-)

  # split into fields
  s/^\s+//; s/\s+$//;
  my ($type, $skip1, $skip2, $local_con, $remote_con, $state);
  if ($^O =~ m/cygwin/)
  {
    ($type, $local_con, $remote_con, $state) = split(/\s+/);
  }
  else
  {
    ($type, $skip1, $skip2, $local_con, $remote_con, $state) = split(/\s+/);
  }
  map { s/^::f+://g; } $local_con, $remote_con;

  my ($local_ip, $local_port) = split(/:/, $local_con);
  die "can't get Local IP from <$local_con>, LINE: <$_>\n" unless $local_ip;
  die "can't get Local Port from <$local_con>, LINE: <$_>\n" unless $local_port;

  my ($remote_ip, $remote_port) = split(/:/, $remote_con);
  die "can't get Remote IP from <$remote_con>, LINE: <$_>\n" unless $remote_ip;
  die "can't get Remote Port from <$remote_con>, LINE: <$_>\n" unless $remote_port;

  # get the service names (eg: ssh, telnet, ftp), both for remote and local
  # - if we can...
  my $local_service = getservbyport($local_port, $type);
  my $remote_service = getservbyport($remote_port, $type);

  # resolve the IP addresses (remote and local)
  my $local_host = gethostbyaddr(inet_aton($local_ip), AF_INET) || $local_ip;
  my $remote_host = gethostbyaddr(inet_aton($remote_ip), AF_INET) || $remote_ip;

  # filter some routine connections
  next if !$opt_a and !$local_service and !$remote_service and $local_host eq $remote_host and $local_port =~ m/^\d+$/ and $remote_port =~ m/^\d+$/;

  my $l_port = $local_service || $local_port;
  my $r_port = $remote_service || $remote_port;

  my ($out, $l_h, $l_p, $r_h, $r_p);
  if ($remote_service)
  {
    $out .= "($local_host:$l_port) -> ($remote_host:$remote_service)";
    ($l_h, $l_p, $r_h, $r_p) = ($local_host, $l_port, $remote_host, $remote_service);
  }
  elsif ($local_service)
  {
    $out .= "($remote_host:$r_port) -> ($local_host:$local_service)";
    ($l_h, $l_p, $r_h, $r_p) = ($remote_host, $r_port, $local_host, $local_service);
  }
  else
  {
    # having specific cases is not the most elegant...
    if ($local_port > $remote_port or $remote_port =~ m/^(6000|48001)$/)
    {
      $out .= "($local_host:$l_port) -> ($remote_host:$r_port)";
      ($l_h, $l_p, $r_h, $r_p) = ($local_host, $l_port, $remote_host, $r_port);
    }
    else
    {
      $out .= "($remote_host:$r_port) -> ($local_host:$l_port)";
      ($l_h, $l_p, $r_h, $r_p) = ($remote_host, $r_port, $local_host, $l_port);
    }
  }

  # PRINT
  # - filters out duplicate connections
  print "$state: $out\n" unless $seen{ $l_h . $r_h . $r_p}++;
}
close(NS);

# EOF
