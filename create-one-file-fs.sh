#!/bin/bash
#
# Script to create a one-file FS (vfat/ext4) - useful for Live Linux USBs
# - takes care of creation of the FS
# - mounting/unmounting
#
# * By Kordian W. <code [at] kordy.com>, April 2020
#

# what FS do we use?
# - vfat: if using on FAT32
# - ext4: if using on other
DEFAULT_FS_TYPE=vfat

# what are the MOUNT OPTIONS?
MOUNT_OPTIONS="loop,rw,relatime,user,uid=$(id -u),gid=$(id -g)"


####################

#
# FUNCTIONS
#
function create_fs_and_mount()
{
  FILE=$1
  SIZE=$2
  MOUNT=$3
  [ -z "$FILE" ] && { echo "$PROG: no file supplied!" >&2; exit 99; }
  [ -z "$SIZE" ] && { echo "$PROG: no size supplied!" >&2; exit 99; }
  [ -z "$MOUNT" ] && { echo "$PROG: no mount supplied!" >&2; exit 99; }

  [ -e "$FILE" ] && { echo "$PROG: File << $FILE >> already exists:" >&2; ls -loh $FILE; exit 99; }
  [ -e "$MOUNT" ] && { echo "$PROG: Mount dir << $MOUNT >> already exists:" >&2; ls -ld $MOUNT; exit 99; }

  echo "* creating << $DEFAULT_FS_TYPE >> one-file FS << $FILE >> with the size of << $SIZE >>" >&2

  # create the file
  sudo dd if=/dev/zero of=$FILE bs=1 count=0 seek=$SIZE || exit 1

  echo -e "\n* created the file $FILE:" >&2
  ls -loh $FILE || exit 2

  echo -e "\n* format the file $FILE as $DEFAULT_FS_TYPE" >&2
  sudo /sbin/mkfs.$DEFAULT_FS_TYPE $FILE || exit 3

  echo -e "\n* mounting as local mount << $MOUNT >>" >&2
  mkdir $MOUNT || exit 4
  sudo mount -v -o $MOUNT_OPTIONS -t $DEFAULT_FS_TYPE $FILE $MOUNT || exit 5

  echo -e "\n* viewing the local mount << $MOUNT >>" >&2
  df -Th | grep "$MOUNT"
}

function mount_fs()
{
  FILE=$1
  MOUNT=$2
  [ -z "$FILE" ] && { echo "$PROG: no file supplied!" >&2; exit 99; }
  [ -z "$MOUNT" ] && { echo "$PROG: no mount supplied!" >&2; exit 99; }

  [ ! -e "$FILE" ] && { echo "$PROG: File << $FILE >> doesn't exist:" >&2; exit 99; }
  [ ! -e "$MOUNT" ] && { echo "$PROG: Mount dir << $MOUNT >> doesn't exist:" >&2; exit 99; }
  [ ! -r "$FILE" ] && { echo "$PROG: File << $FILE >> not readable:" >&2; ls -loh $FILE; exit 99; }
  [ ! -w "$MOUNT" ] && { echo "$PROG: Mount dir << $MOUNT >> not writeable" >&2; ls -ld $MOUNT; exit 99; }

  # is the dir empty?
  if /bin/ls -a $MOUNT |egrep -qv "^\.*$" |egrep "."; then
    echo "$PROG: Mount dir << $MOUNT >> not empty:" >&2
    ls $MOUNT
    exit 2
  fi

  # is it already mounted?
  if df -Th | grep -q "$MOUNT"; then
    echo "$PROG: Mount dir << $MOUNT >> already mounted:" >&2
    df -Th | grep "$MOUNT"
    exit 3
  fi
  if mount | grep -q "$MOUNT"; then
    echo "$PROG: Mount dir << $MOUNT >> already mounted:" >&2
    mount | grep "$MOUNT"
    exit 4
  fi

  echo "* working out FS-TYPE of one-file FS << $FILE >> " >&2
  TYPE=`file $FILE`
  if echo "$TYPE" | egrep -q "mkfs.fat|vfat"; then FS_TYPE=vfat; fi
  if echo "$TYPE" | egrep -q "ext2|EXT2"; then FS_TYPE=ext2; fi
  if echo "$TYPE" | egrep -q "ext3|EXT3"; then FS_TYPE=ext3; fi
  if echo "$TYPE" | egrep -q "ext4|EXT4"; then FS_TYPE=ext4; fi
  [ -z "$FS_TYPE" ] && { echo -e "$PROG: can't work out FS type of << $FILE >> from string:\n" >&2; file $FILE; exit 99; }

  echo "* mounting one-file << $FS_TYPE >> FS << $FILE >> on mount dir << $MOUNT >>" >&2
  sudo mount -v -o $MOUNT_OPTIONS -t $FS_TYPE $FILE $MOUNT || exit 5

  echo -e "\n* viewing the local mount << $MOUNT >>" >&2
  df -Th | grep "$MOUNT"
}

function umount_fs()
{
  MOUNT=$1
  [ -z "$MOUNT" ] && { echo "$PROG: no mount supplied!" >&2; exit 99; }

  [ ! -e "$MOUNT" ] && { echo "$PROG: Mount dir << $MOUNT >> doesn't exist:" >&2; exit 99; }
  [ ! -r "$MOUNT" ] && { echo "$PROG: Mount dir << $MOUNT >> not readable" >&2; ls -ld $MOUNT; exit 99; }

  # is it mounted?
  if ! df -Th | grep -q "$MOUNT"; then
    echo "$PROG: Mount dir << $MOUNT >> is not mounted!" >&2
    df -Th | grep "$MOUNT"
    exit 3
  fi
  if ! mount | grep -q "$MOUNT"; then
    echo "$PROG: Mount dir << $MOUNT >> is not mounted!" >&2
    mount | grep "$MOUNT"
    exit 4
  fi

  echo "* umounting mount dir << $MOUNT >>" >&2
  sudo umount -v $MOUNT || exit 5
}

#
# MAIN PROGRAM
#
PROG=`basename $0`
if [ "$1" = "-create" -a -n "$2" -a -n "$3" -a -n "$4" ]; then
  create_fs_and_mount $2 $3 $4
elif [ "$1" = "-mount" -a -n "$2" -a -n "$3" ]; then
  mount_fs $2 $3
elif [ "$1" = "-umount" -a -n "$2" ]; then
  umount_fs $2
else
  cat <<! >&2
$PROG: Script to create one-file FS ($DEFAULT_FS_TYPE)

Usage: $PROG [options] <function>

        -mount <filename> <mount-dir>

           Mounts a previously created one-file FS:
           * <filename>  is the filename, eg: /data/image
           * <mount-dir> is the dir of local mount eg: /mnt/disk

           Example:
           # $PROG -mount /cdrom/Downloads-rw /home/user/Downloads

        -umount <mount-dir>

           Mounts a previously mounted one-file FS:
           * <mount-dir> is the dir of local mount eg: /mnt/disk

           Example:
           # $PROG -umount /home/user/Downloads

        -create <name> <size> <mount-dir>

           Creates the one-file FS ($DEFAULT_FS_TYPE):
           * <filename>  is the filename, eg: /data/image
           * <size>      is the size, eg: 100M, 1G
           * <mount-dir> is the dir of local mount eg: /mnt/disk

           Example:
           # $PROG -create /cdrom/Downloads-rw 4095M /home/user/Downloads

	-h	this screen

!
fi

# EOF
