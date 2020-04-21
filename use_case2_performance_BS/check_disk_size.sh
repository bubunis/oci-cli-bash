#!/bin/bash
## jdf - Copyleft 04/25/2009 - JPmicrosystems - GPL
## Free space on disk
## Custom df output
## Human readable (-h)
## sorted by file system name

## Make a temporary file and put the following awk program in it
AWK=$(/bin/mktemp -q /tmp/jdf.XXXXXX)

## PROG is quoted to prevent all shell expansions
## in the awk program
cat <<'PROG' > ${AWK}
## Won't work if mount points are longer than 21 characters

BEGIN {
  ## Use fixed length fields to avoid problems with
  ## mount point or file system names with embedded blanks
  FIELDWIDTHS = "11 11 6 6 5 5 21"
  printf "\n%s\n\n", "                    Disks present in this host"
  printf     "%s\n", "Mount Point          Avail Size  Used  Use%  Filesystem Type"
}

## Eliminate some filesystems
## That are usually not of interest
## anything not starting with a /

! /^\// { next }

## Rearrange the columns and print

{
  TYP=$2
  gsub("^ *", "", TYP)
  printf "%-21s%6s%6s%5s%5s %s%s\n", $7, $5, $3, $4, $6, $1, TYP
}

END { print "" }
PROG

df -hT | tail -n +2 | sort | gawk -f ${AWK}

rm -f ${AWK}

