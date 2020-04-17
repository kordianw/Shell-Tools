#!/bin/bash
#
# Script to fix Cygwin Permissions
# - useful when permissions are screwed up on a Windows system
#
# * By Kordian Witek <code [at] kordian.com>, March 2011
#

####################
PROG=`basename $0`
if [ "$1" = "-h" ]; then
  cat <<! >&2
$PROG: Script to fix Cygwin Permissions

Usage: $PROG <options> [param]
	-h	this screen
!
else
  USER=`whoami`
  [ -n "$USER" ] || exit 1 

  # home-dir actions
  if [ `pwd` = $HOME ]; then
    echo "* securing SSH"
    chown -c $USER $HOME/.ssh
    chown -c $USER $HOME/.ssh/*
    chown -c -R $USER $HOME/*
    chmod -c 600 $HOME/.ssh/*
    chmod -c 700 .ssh

    echo "* working on .* files"
    chown -c -R $USER .*rc .*rc* .*profile* .*env*
    chmod -c -R a-x .*rc .*rc* .*profile* .*env*
    chmod -c 600 .signature .plan .aliases .emacs .email .forward .viminfo .Xdefaults .zcompdump .lynx_bookmarks.html .wget-hsts .sysmanpath 2>/dev/null
    chmod -c 700 .local/ .cache/ .gnupg/ .lftp/ .links/ .ncftp/ .vim/ .w3m/ .zsh/ .cpan 2>/dev/null
  fi

  echo "* making archives, media and movies: 644"
  chmod -c -R 644 *.tar *.gz *zip *.7z *.rpm *.deb *.rar *.jpg *.jpeg *.gif *.avi *.mov *.mp3 *.mp4 *.m4v 2>/dev/null
  chmod -c -R 644 */*.tar */*.gz */*.rpm */*.deb */*.rar 2>/dev/null

  echo "* sorting out executables & scripts"
  chmod -c 755 pub/ lib/ public_html/ bin/ 2>/dev/null

  chmod -c -R 644 *.pm README README* CHANGELOG TODO .gitignore 2>/dev/null
  chmod -c -R 644 */*.pm */README */README* */CHANGELOG */TODO 2>/dev/null

  chmod -c -R 755 *.pl *.sh *.py *.vbs *.cgi 2>/dev/null
  chmod -c -R 755 */*.pl */*.sh */*.py */*.cgi 2>/dev/null

  echo "* recursive: wider scale removal of exe bit (slow, pls wait)..."
  chmod -c -R a-x *.txt *.xml *.yaml *.html *.htm *.db *.bkup *.old *.ini *.conf *.db *.tmp *.swp *.c *.h *.cpp *.java README* TODO* 2>/dev/null

  # dirs/files - make sure the owner can read/write
  echo "* recursive: make sure the owner can access (slow, pls wait)..."
  find -type d -exec chmod -c u+rwx {} \;
  find -type f -exec chmod -c u+rw {} \;
fi

# EOF
