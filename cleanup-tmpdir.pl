#!/usr/bin/perl -w
#
# Script to remove temporary files older than x number of days
#
# * By Kordian W. <code [at] kordy.com>, Sep 2021
#

use strict;
use warnings;

# Files older than how many days to delete?
my $threshold_days = 10;


##########################
(my $prog = $0) =~ s#.*/##;    # script name

# Make sure the parameters are OK and it's the right directory
die "$prog: You haven't specified which TMP directory to clean files over $threshold_days days!\n" unless my $dir = shift;
die qq|$prog: TMP Directories need to start with slash!\n| unless $dir =~ m#^/\w+#;
die qq|$prog: You can only clean "tmp" directories!\n| unless $dir =~ m#/tmp#;
die qq|$prog: The directory "$dir" doesn't exist!\n|   unless -d $dir;
die qq|$prog: You don't have read access to "$dir"!\n| unless -r $dir;
die qq|$prog: You don't have write access to "$dir"!\n| unless -w $dir;

# open the directory and read all files
opendir DIR, $dir
  or die "$prog: Can't open $dir: $!\n";
my @files = grep { -f "$dir/$_" } readdir DIR;
closedir DIR;

# Start the count
my $count = 0;

# Print an informative message
print qq|$prog: Starting the deletion process on "$dir" on |, scalar localtime, ":\n";
print qq|$prog: Deletion threshold is $threshold_days days - deleting files older than $threshold_days days.\n|;

#
# Do the actual deletion using a separate sub-routine to which we pass filename
#
&process_file($dir . "/" . $_) foreach (@files);

# Print an informative message
print qq|$prog: Script finished - deleted $count file(s).\n|;

#
# processes individual file
#
sub process_file
{
  my ($file) = @_;
  die "require file param!\n" unless $file;
  die "file `$file' doesn't exist!\n" unless -e $file;
  die "file `$file' is not a file!\n" unless -f $file;

  # Find last access time and last modification time of the file
  my ($atime, $mtime) = (stat $file)[8, 9];

  # Convert threshold (in days) to seconds
  my $thres_secs = $threshold_days * 24 * 60 * 60;

  # Delete only if both atime and mtime are earlier than the threshold
  if ((time - $mtime) > $thres_secs)
  {
    if (-w $file)
    {
      print ++$count . qq|. Deleting "$file" on |, scalar localtime, " ...\n";
      unlink $file;
    }
  }
}

# EOF
