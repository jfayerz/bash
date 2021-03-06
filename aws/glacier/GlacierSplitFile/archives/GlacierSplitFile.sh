#!/bin/bash

FILE1=$1 # name of the target file
VAULTNAME=$2 # expected input from cli, this is your glacier vault name
DESCRIPTION=$3 # expected input from cli contained between a set of double quotes
USER1=$(whoami) # user name. this is used if the homedir needs to be referenced
SIZE1=$(stat --printf="%s" $FILE1) # Size of the target file in bytes, only
DIR="$FILE1-aws" # directory named after target file with something appended

PARTSIZE=1048576 # Sets part size in bytes. AWS Glacier REQUIRES your part sizes
                 # to be in powers of two. So, one MB, two MB, four MB, etc.
                 # and it deals with them in bytes
                 # see glacier reference for more

##############################################################################
# This next part is an attempt to find out how many parts there should be for 
# the upload. It turns out to be beside the point because once the file is 
# split I can simply count Those parts at that point.
# But it could be useful as some kind of check and balance.
#
# Calculates the decimal/fraction of how many parts
# PARTS=$(echo "scale=1;$SIZE1/$PARTSIZE" | bc -l)
#
# Does the same, but drops the decimal. Useful for comparison only.
# let PARTS2=$SIZE1/$PARTSIZE
#
# Compares the decimal with the non-decimal to see how many parts we should
# end up with post-split. Useful only as a check
# if [ $(bc<<<$PARTS==$PARTS2) = 1 ]
# then
#         PARTS3=$PARTS
#         echo $PARTS3
# else
#         let PARTS3=$PARTS2+1
#         echo $PARTS3
# fi
#############################################################################

mkdir $DIR # creates the directory where the log files and the split files will
           # be stored

# "treehash" uses ruby to calculate TreeHash and place it into a log file.
# see https://github.com/erichmenge/treehash for the ruby gem and install 
# Directions
# This is slightly simpler than using the java version of the TreeHash, but
# if you want to use Java then comment this line out and uncomment the java ln
TREEHASH=$(treehash $FILE1)
echo $TREEHASH > "$DIR/TreeHash.log"

# uses Java to run the class file against the file and place the TreeHash into 
# the log file.  This Bash script uses the ruby gem by default.
# Remove the "#" from the beginning of the next line and place a "#" in front 
# of the "treehash $FILE1 > "$DIR/TreeHash.log"" line above
# Also, copies the TreeHashExample.class file from the location listed

# cp /home/$USER1/Documents/TreeHash/TreeHashExample.class ./ # this expects 
                                                              # the java class
                                                              # to be ready to 
                                                              # go and located 
                                                              # in your 
                                                              # $HOME/Documents/TreeHash 
                                                              # directory
# java TreeHashExample "$FILE1" > "$DIR/TreeHash.log"

# splits the file based on the $PARTSIZE entered above. 
split -a5 -d -b $PARTSIZE "$FILE1" "$DIR/$FILE1-Part-"  

PARTS=$(find "$DIR/" -type f -name "*-Part-*" | wc -l)
echo $PARTS

# this assigns the output of the aws initiate multipart upload command, the 
# upload id in this case, to the UPLOADID variable.
# "grep" looks for the uploadId of the json output
# "awk" looks for the field separator (-F) ":" and prints the second field
# The output from grep is only one line, th uploadId line. So the data passed
# to awk is only "uploadId": "thenumber", including the ending comma and
# beginning double quote
# awk then finds the second position using the colon as the seperator and
# passes that ' "thenumber",' (ignore the single quotes and take note of the 
# preceding space).
# sed then finds ' "' (space, doublequote) and replaces it with nothing
# then finds '"," (double quote, comma) and replaces it with nothing, 
# leaving just the uploadId itself
# that uploadId is then assigned to $UPLOADID and subsequently recorded in $DIR
UPLOADID=$(aws glacier initiate-multipart-upload --account-id - --vault-name $VAULTNAME --part-size $PARTSIZE --archive-description "$DESCRIPTION" | grep uploadId | awk -F: '{ print $2 }' | sed 's/ \"//g; s/\",//g')
echo $UPLOADID > $DIR/uploadid.log

ARRAYNAME=( $(find "$DIR/" -type f -name "*Part*" -printf "%f\n") )
ARRAYSIZE=( $(find "$DIR/" -type f -name "*Part*" -printf "%s\n") )
SP=0
COUNTY=0

while [ $PARTS -gt 0 ]
do
        let ENDSIZE=$(( $COUNTY + $(( ${ARRAYSIZE[$SP]} - 1 )) ))

        # below, in the --range area i had to use double quotes instead of 
        # single because single quotes were playing hell with the bash script.
        # It does not work with single quotes as far as I know, but it works
        # fine with double.
        aws glacier upload-multipart-part --account-id - --vault-name $VAULTNAME --upload-id $UPLOADID --body $DIR/$(echo ${ARRAYNAME[$SP]}) --range "bytes $(echo $COUNTY)-$(echo $ENDSIZE)/*" >> "$DIR/FileChecksums.log"

        COUNTY=$(( $COUNTY + ${ARRAYSIZE[$SP]} ))
        SP=$(( $SP + 1 ))
        PARTS=$(( $PARTS - 1 ))
done

aws glacier complete-multipart-upload --account-id - --vault-name $VAULTNAME --upload-id $UPLOADID --checksum $TREEHASH --archive-size $SIZE1 > "$DIR/Completion.log"
cat "$DIR/Completion.log"
