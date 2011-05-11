#!/bin/bash
#set -x
# full and incremental backup script
# created 07 February 2000
# Based on a script by Daniel O'Callaghan <danny@freebsd.org>
# modified by Gerhard Mourani <gmourani@videotron.ca>
# modified by Jose Da Silva <Digital@JoesCat.com> 05/feb/08
# modified by Jose Da Silva <Digital@JoesCat.com> 08/sep/10
# modified by Tarjei Huse <tarjei.huse@gmail.com> 11/may/11
#
# This script was originally based on above script shown on
# <http://www.faqs.org/docs/securing/chap29sec306.html> and was
# modified to backup several directories plus keep a "lastweek"
# "prevweek" and "priorweek" backups too, and report errors.
#
# If you need to backup directories which contain active files,
# it is recommended that you do a snapshot of those directories
# and then do a backup of the snapshot, this way, you have less
# problems dealing with file-locks and files in transition.
# If you need to run a snapshot first, just insert a call to the
# appropriate script at the beginning/end of the main routine below.
#
# Change the variables below to fit your computer/backup system

# Reduce list of paths to trusted directories (most->least trusted)
PATH=/bin:/usr/bin:/usr/local/bin

# Name and location of commands so you don't need to search paths
TAR=/bin/tar            # Name and location of commands
BASENAME=/usr/bin/basename      # Use "which" to find commands, but
CAT=/bin/cat            # try to check /bin before using
DATE=/bin/date          # commands located elsewhere such as
ECHO=/bin/echo          # in /usr/local/bin or in /usr/bin
CHMOD=/bin/chmod
CHOWN=/bin/chown
HOSTNAME=/bin/hostname
MKDIR=/bin/mkdir
MV=/bin/mv
WHOAMI=/usr/bin/whoami

COMPUTER=`hostname` # Name of this computer
DIRS=( "/home" "/etc"  )       # Directories to backup daily
BKDIR=/backup          # Where to store all the backup
TIMEDIR=/backup/last-full  # Where to store time of full backup
ERRFILE=/var/log/syslog     # Send error messages to this file
BKOWNER=root.adm        # Owner and Group for backup files
CHMODCHOWN=1            # This file system can use chmod+chown
FULL_WEEK_DAY="Sun"

if [ $# -eq 1 ] 
then
   . $1
fi
if [ -z "$PS1" ]; then
# not an interactive shell, assume we are running as a cronjob
else
    printConfig
fi

function printConfig() {
    cat <<EOD
    Starting backup of $COMPUTER with config:
    Day of week to do full backups: $FULL_WEEK_DAY
    Backup directory: $BKDIR

    Directories to backup:
    EOD
    for element in $(seq 0 $((${#DIRS[@]} - 1)))
        do
        echo  "${DIRS[$element]}"
    done
}

DOW=`$DATE +%a`         # Day of the week e.g. Mon
DOM=`$DATE +%d`         # Date of the Month e.g. 27
MD=`$DATE +%b%d`        # Month and Date e.g. Sep27
MDT=`$DATE +"%b %d %T"`     # Month Day Time Sep 27 12:00:00
CMD=`$BASENAME "$0"`        # Command Line Program
EM="$MDT `$HOSTNAME` $CMD[$$]:" # Error Message info

errortmp=0          # Temporary error accumilator
errors=0            # 0 if no errors found at all

# On the 1st of the month, do permanent full backups.
#
# Every Sunday, prevweek's backup is pushed to priorweek's backup,
# lastweek's backup pushed to prevweek's backup, and then Sunday's
# backup is pushed to lastweek's backup before creating a Sunday
# full backup. This creates 4 weeks worth of rollover backups.
#
# Monday to Saturday, an incremental backup is made based on Sunday
# so that you you have daily backups for new files until next week.
#
# if NEWER = "", then tar backs up all files in the directories
# otherwise it backs up files newer than the NEWER date. NEWER
# gets its date from the file written every Sunday.

ErrorTest () {
  # Check exit status of last command for any errors and set flag
  if [ "$?" -ne 0 ]; then
    errortmp=1;
  fi
}

ErrorSet () {
  # Set errors if errortmp=1 and send error message to $ERRFILE
  if [ $errortmp -eq 1 ]; then
    $ECHO "$EM Error $1" >> $ERRFILE;
    errors=1
  fi
}

UpdateTheDate() {
  # Update full backup date so increments happen after this
  errortmp=0;
  NOW=`$DATE +"%Y-%m-%d %X"`; ErrorTest;
  $ECHO "$NOW" > "$TIMEDIR/$COMPUTER-full-date"; ErrorTest;
  if [ $CHMODCHOWN -eq 1 ]; then
    $CHMOD 640 "$TIMEDIR/$COMPUTER-full-date"; ErrorTest;
    $CHOWN $BKOWNER "$TIMEDIR/$COMPUTER-full-date"; ErrorTest;
  fi
  ErrorSet "with time stamp $TIMEDIR/$COMPUTER-full-date";
}

MakeFullMonthlyBackup() {
  # Make a full monthly backup based on given directories
  errortmp=0;
  $TAR -cpzf "$BKDIR/$COMPUTER-$MD-$1.tar.gz" "$2"; ErrorTest;
  if [ $CHMODCHOWN -eq 1 ]; then
    $CHMOD 640 "$BKDIR/$COMPUTER-$MD-$1.tar.gz"; ErrorTest;
    $CHOWN $BKOWNER "$BKDIR/$COMPUTER-$MD-$1.tar.gz"; ErrorTest;
  fi
  ErrorSet "with tar file $BKDIR/$COMPUTER-$MD-$1.tar.gz";
}

MakeFullWeeklyBackup() {
  # Move previous week's backups into prior week's backups
  errortmp=0;
  if [[ -f "$BKDIR/$COMPUTER-$DOW-prevweek-$1.tar.gz" ]]; then
    $MV "$BKDIR/$COMPUTER-$DOW-prevweek-$1.tar.gz" \
        "$BKDIR/$COMPUTER-$DOW-priorweek-$1.tar.gz"; ErrorTest;
    if [ $CHMODCHOWN -eq 1 ]; then
      $CHMOD 640 "$BKDIR/$COMPUTER-$DOW-priorweek-$1.tar.gz";
      ErrorTest;
      $CHOWN $BKOWNER "$BKDIR/$COMPUTER-$DOW-priorweek-$1.tar.gz";
      ErrorTest;
    fi
    ErrorSet "moving $BKDIR/$COMPUTER-$DOW-prevweek-$1.tar.gz";
  fi
  # Move last week's backups into previous week's backups
  errortmp=0;
  if [[ -f "$BKDIR/$COMPUTER-$DOW-lastweek-$1.tar.gz" ]]; then
    $MV -f "$BKDIR/$COMPUTER-$DOW-lastweek-$1.tar.gz" \
           "$BKDIR/$COMPUTER-$DOW-prevweek-$1.tar.gz"; ErrorTest;
    if [ $CHMODCHOWN -eq 1 ]; then
      $CHMOD 640 "$BKDIR/$COMPUTER-$DOW-prevweek-$1.tar.gz";
      ErrorTest;
      $CHOWN $BKOWNER "$BKDIR/$COMPUTER-$DOW-prevweek-$1.tar.gz";
      ErrorTest;
    fi
    ErrorSet "moving $BKDIR/$COMPUTER-$DOW-lastweek-$1.tar.gz";
  fi
  # Then move this week's full backups into last week's backups
  errortmp=0;
  if [[ -f "$BKDIR/$COMPUTER-$DOW-$1.tar.gz" ]]; then
    $MV "$BKDIR/$COMPUTER-$DOW-$1.tar.gz" \
        "$BKDIR/$COMPUTER-$DOW-lastweek-$1.tar.gz"; ErrorTest;
    if [ $CHMODCHOWN -eq 1 ]; then
      $CHMOD 640 "$BKDIR/$COMPUTER-$DOW-lastweek-$1.tar.gz";
      ErrorTest;
      $CHOWN $BKOWNER "$BKDIR/$COMPUTER-$DOW-lastweek-$1.tar.gz";
      ErrorTest;
    fi
    ErrorSet "moving weekly file $BKDIR/$COMPUTER-$DOW-$1.tar.gz";
  fi
  # Then create a new weekly backup for this day-of-week
  errortmp=0;
  $TAR -cpzf "$BKDIR/$COMPUTER-$DOW-$1.tar.gz" "$2"; ErrorTest;
  if [ $CHMODCHOWN -eq 1 ]; then
    $CHMOD 640 "$BKDIR/$COMPUTER-$DOW-$1.tar.gz"; ErrorTest;
    $CHOWN $BKOWNER "$BKDIR/$COMPUTER-$DOW-$1.tar.gz"; ErrorTest;
  fi
  ErrorSet "with weekly file $BKDIR/$COMPUTER-$DOW-$1.tar.gz";
}

MakeIncrementalWeeklyBackup() {
  # Make an incremental backup based on date in NEWER file
  errortmp=0;
  $TAR --newer="$1" -cpzf "$BKDIR/$COMPUTER-$DOW-$2.tar.gz" "$3";
  ErrorTest;
  if [ $CHMODCHOWN -eq 1 ]; then
    $CHMOD 640 "$BKDIR/$COMPUTER-$DOW-$2.tar.gz"; ErrorTest;
    $CHOWN $BKOWNER "$BKDIR/$COMPUTER-$DOW-$2.tar.gz"; ErrorTest;
  fi
  ErrorSet "with incremental file $BKDIR/$COMPUTER-$DOW-$2.tar.gz";
}

#----- Main program starts here -----
if [ "`$WHOAMI`" != "root" ]; then
  $ECHO "$EM Sorry, you must be root!";
  exit 1
fi


# Verify backup directory exists, otherwise create it.
if [[ ! -d "$BKDIR" ]]; then
  $MKDIR "$BKDIR"
  if [[ ! -d "$BKDIR" ]]; then
    $ECHO "$EM Error, cannot make $BKDIR!" >> $ERRFILE;
    $ECHO "$EM Error, no backup files made!" >> $ERRFILE;
    exit 2
  else
    if [ $CHMODCHOWN -eq 1 ]; then
      errortmp=0;
      $CHMOD 740 "$BKDIR"; ErrorTest;
      $CHOWN $BKOWNER "$BKDIR"; ErrorTest;
      ErrorSet "setting permissions on directory $BKDIR";
    fi
  fi
fi

# Verify time directory exists, otherwise create it.
if [[ ! -d "$TIMEDIR" ]]; then
  $MKDIR "$TIMEDIR"
  if [[ ! -d "$TIMEDIR" ]]; then
    $ECHO "$EM Error, cannot make $TIMEDIR!" >> $ERRFILE;
    $ECHO "$EM Error, no backup files made!" >> $ERRFILE;
    exit 3
  else
    if [ $CHMODCHOWN -eq 1 ]; then
      errortmp=0;
      $CHMOD 640 "$TIMEDIR"; ErrorTest;
      $CHOWN $BKOWNER "$TIMEDIR"; ErrorTest;
      ErrorSet "setting permissions on directory $TIMEDIR";
    fi
  fi
fi

# Verify time file exists, otherwise create it.
if [[ ! -f "$TIMEDIR/$COMPUTER-full-date" ]]; then
  UpdateTheDate;
  if [[ ! -f "$TIMEDIR/$COMPUTER-full-date" ]]; then
    $ECHO "$EM Error, cannot find $TIMEDIR/$COMPUTER-full-date!" \
      >> $ERRFILE;
    $ECHO "$EM Error, no backup files made !" >> $ERRFILE;
    exit 4
  else
    if [ $CHMODCHOWN -eq 1 ]; then
      errortmp=0;
      $CHMOD 640 "$TIMEDIR/$COMPUTER-full-date"; ErrorTest;
      $CHOWN $BKOWNER "$TIMEDIR/$COMPUTER-full-date"; ErrorTest;
      ErrorSet "setting permissions, $TIMEDIR/$COMPUTER-full-date";
    fi
  fi
fi

# Create Monthly Backups on 1st day of each month
if [ $DOM = "01" ]; then
    for element in $(seq 0 $((${#DIRS[@]} - 1)))
    do
        DIR="${DIRS[$element]}"
        NAME=`echo $DIR|sed 's/\//-/g'`
        MakeFullMonthlyBackup $NAME $DIR;
    done
fi

#if [ $DOW = "Sun" ]; then
if [ $DOW = $FULL_WEEK_DAY ]; then
  # Create Full Weekly Backups on Sundays
  for element in $(seq 0 $((${#DIRS[@]} - 1)))
  do
        DIR="${DIRS[$element]}"
        NAME=`echo $DIR|sed 's/\//-/g'`
        MakeFullWeeklyBackup $NAME $DIR;
  done
  UpdateTheDate;
else
  # Make incremental backups - overwrite last weeks

  # Get date of last full backup
  NEWER="`$CAT $TIMEDIR/$COMPUTER-full-date`"
  for element in $(seq 0 $((${#DIRS[@]} - 1)))
  do
    DIR="${DIRS[$element]}"
        NAME=`echo $DIR|sed 's/\//-/g'`
        MakeIncrementalWeeklyBackup "$NEWER" $NAME $DIR;
  done
fi

#if [ $errors -eq 1 ]; then
#  # Errors were found while doing a backup, warn someuser!
#  $ECHO "$EM Error creating backups!" >> \
#    /home/someuser/Desktop/warning.txt
#  $CHMOD 777 /home/someuser/Desktop/warning.txt
#fi
