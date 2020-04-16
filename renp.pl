#!/usr/bin/perl -w
# script to rename files recursively, given a pattern.
#
# By Kordian Witek <code@kordian.com>, December 2000.
#
use Cwd;
use File::Basename;
use File::Find;
use File::Copy;
use Getopt::Std;
use vars qw($opt_r $opt_d $opt_O);


###############
# Main program
$prog = &basename($0);

# parse params & get the regular expression
die qq|$prog: Use "-r" to rename files recursively & "-d" to include directory names.\n\n| . &usage unless &getopts('lrdstFO');
unless ($opt_l or $opt_s or $opt_F or $opt_t)
{
  die &usage unless ($pattern, $replace, $global) = &parse_pattern(@ARGV);
}

$dest = &prepare();
if ($opt_r)
{
  &find(\&process, $dest);			# recursive mode
}
else
{
  opendir(CUR, $dest)
    or die qq|$prog: Can't read directory "$dest"!...\n|;
  if ($opt_d or $opt_F)
  {
    &process foreach (grep { !/^\./ } readdir(CUR))
  }
  else
  {
    &process foreach (grep { !/^\./ && -f "$dest/$_" } readdir(CUR))
  }
  closedir CUR;
}

# A little informative message.
if (defined $found)
{
  print "$prog: Processed the total of $found file(s).\n";
}
else
{
  (my $fdest = $dest) =~ s#.*/(.*?/.*)#$1#;
  print "$prog: No files found matching pattern in `$fdest'";
  print " and below" if $opt_r;
  print " (scanned $scanned files)" if $scanned;
  print "\n";
}


###############
#
# Process the files
#
sub process
{
  $scanned++;
  my ($orig, $no) = $_;

  if ($opt_l)
  {
    s/(.*)/\L$1/;
    s/ +/_/g if $opt_s;
  }
  elsif ($opt_t)
  {
    s#(^|\s)([a-z])#$1\U$2#g;
  }
  elsif ($opt_s)
  {
    s/ +/_/g;
  }
  elsif ($opt_F)
  {
    $opt_d++;
    my $input;

    my $no = grep(!/[\w \.\&\+~(),'`\[\]\$!#%-]+/, split '');
    if ($no)
    {
      print qq|Enter $no rep-chars for << $_ >>: |;
      do
      {
        chop($input = <STDIN>);
        print "   ... please enter $no replacement chars: " unless length($input) == $no;
      }
      until length($input) == $no;

      # go through and replace weird chars
      foreach my $c (split '', $input)
      {
        s/[^\w \.\&\+~(),'`\[\]\$!#%-]/$c/;
      }
    }
  }
  else
  {
    # regular expressions that process the file
    s/$pattern/$replace/g if $global;
    s/$pattern/$replace/ unless $global;

    # back-substitute any $n (eg $1, $2, etc) patterns
    while (++$no)
    {
      if ($orig =~ /$pattern/ and ${$no}) 
      {
        last unless my $replace = ${$no};
        s/\$$no/$replace/;
      }
      else { last; }
    }

    # some upper/lower casing if it was requested...
    s#\\u(.)#\u$1#; s#\\U(.*)#\U$1#;
    s#\\l(.)#\l$1#; s#\\L(.*)#\L$1#;
  }

  # undo if in recursive mode we don't want to rename directories
  if ($opt_r and !$opt_d)
  {
    unless (-f $orig)
    {
      $scanned--;
      $_ = $orig;
    }
  }

  # do rename only on files that actually differ!
  if ($orig ne $_)
  {
    $found++;

    my $dest_dir = $opt_r ? &dirname($File::Find::name) : &cwd;
    print "Found in: $dest_dir/\n" if $opt_r;

    unless ($opt_O)
    {
      die qq|\n*** WARNING: "$_" already exists! ***\n| if -e;
    }

    print "Orig: $orig\nNew:  $_\nRename this ", -f $orig ? "file":"directory", "? [y/N]: ";
    if (<STDIN> =~ /y/i)
    {
      unless (-l $orig)
      {
        die qq|You don't have permission to rename "$orig", quitting...\n| unless -w $orig;
      }

      # we rename to ".old" first and then to the real new name, cos of vfat.
      &move($orig, $orig . ".old")
        or die qq|$prog: rename of "$orig" to "$orig.old" failed: $!\n|;

      &move($orig . ".old", $_)
        or die qq|$prog: rename of "$orig.old" to "$_" failed: $!\n|;
    }
    print "\n";
  }
}

#
# prepare for the process of processing of the files/directories
#
sub prepare
{
  # is this a valid directory?
  die qq|$prog: "$dest" is not a valid directory, exiting.\n| unless -d ($dest = &cwd);

  # can we write to this directory?
  die qq|$prog: You don't have WRITE access to dir "$dest", exiting.\n| unless -w $dest;

  return $dest;
}

#
# parse the pattern - be strict to make sure valid pattern is given
#
sub parse_pattern
{
  die &usage unless @_;
  if ($ARGV[0] and $ARGV[1])
  {
    die qq|$prog: The pattern should be of the form "FROM" "TO" [g].\n| if $ARGV[2] and $ARGV[2] ne 'g';
    return ($ARGV[0], $ARGV[1], $ARGV[2]);
  }
  else
  {
    die qq|$prog: The pattern should be of the form of "s/pattern/replace/g".\n| unless ($_ = shift) =~ m|^s[/#](.+?)[/#](.*?)[/#](g?)$|;
    return ($1, $2, $3);
  }
}

#
# show usage help...
#
sub usage
{
  return <<"END";
$prog: renames files recursively given pattern + replace regular expression.

Usage: $prog [options] s/pattern/replace/g 

Options: -r	rename files recursively, scanning all subdirectories
         -d	include names of directories
         -l	change file names to lowercase
         -s	change spaces to underscores
         -t	change to "Title Case"
         -F	"foreign" mode -> manually change non-ascii into ascii
         -O     Advanced Mode (do not use)
END
}

# EOF
