#!/bin/bash
#This is the OS X version - you can specify no. hours to ctime
#the scripts aims to copy a list of files saved in a text file from the archives
thefiles=~/files.$$
#HOME=/home/$(whoami)
HOME=/Users/$(whoami)
#LOCALDIR=/media/sf_nmr-in
LOCALDIR=$HOME/autocopied-nmr-data
#MOUNT=/media/NMRshares
MOUNT=/Volumes/NMRArchive
IGNORE=$HOME/scripts/ignore
#CRSID=yourcrsid
#PASSWORD=yourpassword
#changetime = $1
read -p "Enter your CRSID - " CRSID
read -sp "Enter Admitto password for NMRShares - " PASSWORD
echo
#read -p "Enter number of hours to copy as Nh, so 12h for 12 hours - " changetime
read -p "Enter filename of file list to copy - " FILELIST

echo $PWD
FILES=$PWD/$FILELIST
echo $FILES
#read -p "Enter the quarter and year to search in in the format Qx-20yy so Q2-2022 for the second quarter of 2022 - " QUARTER
echo home directory :- $HOME
echo directory to copy to :- $LOCALDIR
echo Path of filelist : - $FILES
echo 

mkdir -p $LOCALDIR

#sudo mount -t cifs -o username=$CRSID,password=$PASSWORD //nmr-current.ch.private.cam.ac.uk/NMRshares $MOUNT
open 'smb://'"$CRSID"'':''"$PASSWORD"'@nmr-fs.ch.private.cam.ac.uk/NMRArchive'
unset PASSWORD
sleep 10

# Get start and end years from user
read -p "Enter start year: " START_YEAR
read -p "Enter end year: " END_YEAR


# linux- for YEAR in $(seq $START_YEAR $END_YEAR)
for YEAR in $(seq $START_YEAR 1 $END_YEAR)
do
    # Loop through quarters
    for QTR in 1 2 3 4
    do
        # Create QUARTER variable in format Q1-2021, Q2-2021, etc.
        QUARTER="Q${QTR}-${YEAR}"
        echo "Processing quarter: $QUARTER"
        
        # Loop through spectrometers
        for SPECTROMETER in laphroiag lagavulin glenfairn arran tobermory
        do
            REMOTEDIR="$MOUNT/$QUARTER/$SPECTROMETER/chemist/nmr/"
            echo $REMOTEDIR
            cd $REMOTEDIR
            for FILE in $FILES
            do
                echo File to copy - $FILE
                if test -e "$FILE"; then
                    echo Copying from :- $REMOTEDIR     
                    rsync --progress -arvP --files-from=$FILES ./ $LOCALDIR/
                fi
            done
        done
    done
done