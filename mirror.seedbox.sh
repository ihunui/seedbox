#!/bin/bash

source ../.env

SBF="~/files/@unpack"
MOUNT="/mnt/titanshared"
SHARE=//titan/shared
TESTFILE=checkfile.txt

TARGET="/mmedia/@inbox"
DESTINATION="/mmedia/@inbox/@unpack"
TV="/mmedia/tv"
MOVIES="/mmedia/movies"

IFS='
'

now="$(date)"
echo "==== Starting mirror at $now ===="

# check the mount, if not mounted then mount it
if mountpoint -q $MOUNT; then
   echo "File server already mounted"
else
   echo "Mounting file server"
   sudo mount -t cifs $SHARE $MOUNT -o username=$FSU,password=$FSP
fi

# check the mount worked, then run the script
if test -f "/$MOUNT/$TESTFILE"; then
   echo "$TESTFILE exists, MOUNT command worked, continuing."
   echo "Sync seedbox unpack folder to file server"
   rsync -ahtvz $SBU@$SBN:$SBF $MOUNT/$TARGET/

   echo "Process @inbox"
   if [ "$(ls -A $MOUNT/$DESTINATION)" ]; then
      ARRAY=(`find $MOUNT/$DESTINATION/* -type f`)
      COUNT=${#ARRAY[@]}

      if [ "$COUNT" > 0 ]; then
         echo "Move $COUNT files"
         ARRAYINDEX=0
         for i in ${ARRAY[*]}; do
            ((++ARRAYINDEX))
            echo "file $i of $COUNT"
            IFS=/ read -a array2 <<< "$i"
            fromfile=${array2[${#array2[@]} - 1]}
            folder=${array2[${#array2[@]} - 2]}
            if [[ $folder =~ S[0-9]{2}E[0-9]{2} ]]; then
               showep=$(echo $folder | sed -n 's/\([0-9][0-9]*E[0-9][0-9]*\).*/\1/p' | tr '[:upper:]' '[:lower:]')
               showeplen=${#showep}
               show=$(echo ${showep:0:$showeplen - 7} | tr '.' ' ')
               moveto="$MOUNT/$TV/$show/"
            else
               moveto="$MOUNT/$MOVIES/"
            fi

            IFS=. read -a array3 <<< "$i"
            ext=${array3[${#array3[@]} - 1]}
            echo "Moving $folder.$ext"
            [ -d $moveto ] || mkdir -p $moveto
            movefile=$folder.$ext
            move=${movefile// /.}
            movepath=$moveto/$move
            mv $i $movepath
            sleep 1

            frompath=$(echo $i | sed "s/$fromfile//")
            echo "Delete local $frompath"
            rmdir $frompath

            echo "Delete remote files/unpack/$folder/$fromfile"
            ssh "$SBU@$SBN" "rm -R $SBF/$folder"
         done

         echo "Update XBMC"
         curl --data-binary '{ "jsonrpc": "2.0", "method": "VideoLibrary.Scan", "id": "mybash"}' -H 'content-type: application/json;' http://$USR:$PAS@$HST/jsonrpc
      else
         echo "No files to move"
      fi
   fi
   cd ~

else
   echo "MOUNT command failed, exiting"
fi

now="$(date)"
echo "==== Ending mirror at $now ===="
