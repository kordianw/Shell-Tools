#!/bin/bash
# Simple script for creation of a template for a new shell/perl script
# - supports both Perl and Shell
# - sets-up a basic template for a new script
#
# By Kordian Witek <code [at] kordy.com>, Jan 2005
#

# Configuration
HEADER="Kordian Witek <code [at] kordy.com>"
PERL="/usr/bin/perl"


####################
PROG=`basename $0`
if [ $# -eq 0 -o "$1" = "-h" ]; then
  cat <<! >&2
$PROG: Script to create a new script template in current dir ...

Usage: $PROG <script.sh>
	  -h 	this screen
!
else
  DATE=`date "+%B %Y"`
  FILE="$1"

  # some processing and ensuring it can be done & all is OK
  echo "$1" | grep "\." >&/dev/null || FILE="$1.sh"
  [ -e "$FILE" ] && { echo "$PROG: \"$FILE\" already exists!" >&2; exit 1; }
  [ -w . ] || { echo "$PROG: Can't write \"$FILE\" to \"`pwd`\" ..." >&2; exit 1; }
  ( touch "$FILE"; chmod 755 "$FILE" ) || { echo "$PROG: error setting +x permissions..." >&2; exit 1; }

  # shell script
  if echo "$FILE" | grep "\.sh$" >&/dev/null; then

    cat <<EOT | sed "s/DATE/$DATE/" > "./$FILE"
#!/bin/bash
#
# Script to ...
#
# * By $HEADER, DATE
# \$Id\$
#
# * Change Log:
# \$Log\$

####################
PROG=\`basename \$0\`
if [ \$# -eq 0 -o "\$1" = "-h" ]; then
  cat <<! >&2
\$PROG: Script to ...

Usage: \$PROG [options] <param>
	-h	this screen
!
else
  FILE="\$1"
  echo "\$PROG: Processing \"\$FILE\" ..."
  [ -r "\$FILE" ] || { echo "\$PROG: Can't read \"\$FILE\" ..." >&2; exit 1; }
  [ -w . ] || { echo "\$PROG: Can't write \"\$FILE\" to \"\`pwd\`\" ..." >&2; exit 1; }

  echo "\$PROG: Do the business ..."
fi

# EOF
EOT
  elif echo "$FILE" | grep "\.pl$" >&/dev/null; then
    cat <<EOT | sed "s/DATE/$DATE/" > "./$FILE"
#!$PERL -T
#
# Script to ...
#
# * By $HEADER, DATE
# \$Id\$
#
# * Change Log:
# \$Log\$
use strict;
use warnings;

# allow script-dir modules to be found, when running from any dir
BEGIN {
  require FindBin;
  my (\$path) = \$FindBin::RealBin =~ m#^([\w~: \\/-]+)\$#;
  unshift @INC, \$path, "\$path/lib", "\$path/.." if \$path;
}

# use the "common funcs" custom library
use lib qw/. ../;
use CommonFuncs;

# what is the command we want to run?
my \$CMD = "/bin/ls";

# what is the script description, contact details and VERSION?
our \$DESC    = "@(#)KW Processing Tool";
our \$CONTACT = 'Kordian Witek <code [at] kordy.com>';
our \$VERSION = '\$Revision: 1.1 $';                        # this gets automatically set by CVS


####################
our (\$DEBUG, \$opt_h, \$opt_d, \$opt_V);

#
# MAIN PROGRAM
#
&main_program;

#
# main_program(): the main body of this program (script)
#
sub main_program
{
  # setup program
  &setup_program;

  # get data filename
  my \$data_file = \$ARGV[0] || die "you need to specify a data file to work with!\n";

  my @cmd = &run_cmd(cmd => "\$CMD -f \$data_file", daily_cached => "no", verbose => "yes", desc => "getting \$CMD results");
  dmp(@cmd);
}

########## MAIN FUNCTIONS ##################################

########## AUX FUNCTIONS ###################################

#
# setup_program(): any program setup/prep code goes here...
#
sub setup_program
{
  #
  # LOAD MODULE
  #
  require Getopt::Std;

  # parameter handling (return usage info if "-h" is executed)
  die &usage if (\$ARGV[0] and \$ARGV[0] =~ /-hel/i) or !&Getopt::Std::getopts('dhV') or \$opt_h;
  \$DEBUG++   if \$opt_d;
  &version   if \$opt_V;

  # user-id validation
  my \$run_as_root_err = &run_as_root("no");
  die &get_prog_name . ": \$run_as_root_err\n" if \$run_as_root_err;

  # make die() better and catch Ctrl-C
  &improve_DIE;
  &catch_ctrlc;

  # die on warn (this makes the program safer & emphasizes validation)
  &die_on_warn(1) unless \$DEBUG;

  #TODO: make sure we can run the required command
  #die qq|can't run "| . (\$CMD = &catfile(\$CMD)) . qq|" - this is a required executable!\n| unless -x &catfile(\$CMD);
}

#
# usage(): print usage information
#
sub usage
{
  my \$usage = <<"END";
Options: -a     Not implemented
         -b num Not implemented

         Misc:
         -V     Version/Release information
         -d     Debug mode (do not use)
         -h     This help screen

END
  return &add_script_usage_header("[options]", \$usage);
}

# EOF
EOT
  fi
  echo "$PROG: Created a new script-template: \"./$FILE\" ..."
fi

# EOF
