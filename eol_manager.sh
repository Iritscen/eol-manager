#!/bin/bash

# EOL Manager
# Show or change what sort of line endings are used by a text file or directory of text files. You can
# choose to show or change only files of specified suffix(es), as well as only show or change files of a
# specific EOL type. Requires 'dos2unix'.
#
# Recommended width:
# |----------------------------------------------------------------------------------------------------|

IFS="
"

## SAFETY ##
which dos2unix > /dev/null
if [ "$?" -ne 0 ]; then
   echo "Error: 'dos2unix' does not appear to be installed, so the operation cannot be performed." | fmt -w 80
   exit
fi


## VARIABLES ##
OPER_MODE=0
MODE_GET=1
MODE_SET=2
TARGET_ARG=""
TARGET_TYPE=0
TARGET_FILE=1
TARGET_DIR=2
PRINT_ARG=""
PRINT_TYPE=0
FROM_ARG=""
FROM_TYPE=0
TO_ARG=""
TO_TYPE=0
FOR_ARG=""
declare -a SUFFIXES=()
EOL_TYPE=0
TYPE_UNIX=1
TYPE_DOS=2
TYPE_MAC=3
TYPE_MIX=4
TYPE_NONE=5
TYPE_ALL=6
EOL_UNIX=0
EOL_DOS=0
EOL_MAC=0
SHOW_SKIPS=0
bold=$(tput bold)
under=$(tput smul)
norm=$(tput sgr0)
PRINT_TOTAL=0
CONVERT_TOTAL=0
MAC_COUNT=0
DOS_COUNT=0
UNIX_COUNT=0
MIX_COUNT=0
NONE_COUNT=0


## SUPPORT FUNCTIONS ##
# For passing output through the 'fmt' line-wrapping tool
function mypr()
{
   echo $1 | fmt -w 80
}

# Print help page for script and then exit
function helpAndExit()
{
   mypr "Welcome to EOL Manager, a script for looking at and changing end-of-line types in files. This program can be operated in one of four ways:"
   mypr "1. --get [file]"
   mypr "Get the EOL type of a single file."
   echo
   mypr "2. --get [dir] [--only \"suffix1 suffix2\"] [--list \"[Unix|DOS|Mac|mixed|none|all]\"] [--show-skips]"
   mypr "Get the EOL types of a directory of files (recursively)."
   echo
   mypr "The optional '--only' argument allows you to filter by suffix which files will be looked at, e.g. '--only \"c cpp\"' would only look at .c and .cpp files. In this case you will receive a summary of the EOL types found for each suffix when the script concludes. Otherwise all matching files will be looked at and reported on together. Note that binary (non-text) files will be looked at if you supply a suffix that is used by such files, and those files may fail to have their line endings identified."
   echo
   mypr "The optional '--list' argument will print out the names of any files with the specified type: \"Unix\" for Unix/macOS line endings (LF), \"DOS\" for DOS/Windows line endings (CR+LF), \"Mac\" for Classic Mac OS line endings (CR), \"mixed\" for files with a mix of line endings, \"none\" for files with no line endings, and \"all\" to print the type of each file (this is the default setting when not using '--only'; special formatting is used in this last case to visually differentiate the type output). Capitalization of the type name does not matter."
   echo
   mypr "The optional '--show-skips' argument will print to screen the names of any files that were skipped over because they were not believed to be text. Note that this argument has no effect if you are using the '--only' argument, as the suffixes you supply with that argument will be used in place of the test for whether a file is text."
   echo
   mypr "3. --change [file] --to \"[Unix|DOS|Mac]\""
   mypr "Change the EOL type of a file to a specified type. Capitalization of the type name does not matter."
   echo
   mypr "4. --change [dir] [--only [suffix1 suffix2]] --from \"[Unix|DOS|Mac|mixed]\" --to \"[Mac|DOS|Unix]\" [--show-skips]"
   mypr "Convert a directory of files (recursively) from one EOL type to another. You must specify the from-type and to-type. Capitalization of the type names does not matter."
   echo
   mypr "The optional argument '--only' works as explained above. When not used, all text files of the specified EOL type will be converted. When used, all files (text or non-text) will have conversion attempted if they match the supplied suffixes."
   echo
   mypr "The optional '--show-skips' argument works as explained above; it only works when you don't use the '--only' argument, and will show the non-text files that did not have conversion attempted for them."
   echo
   mypr "Note: When not using the '--only' argument with \"--get [dir]\" and \"--change [dir]\", the Unix 'file' command will be used to tell which files in the directory are text and should have their EOL type determined. This heuristic is not guaranteed to work with 100% accuracy, so you may have to use '--only' to force EOL Manager to look at certain files."
   exit
}

# Determine EOL type from output of 'dos2unix', pass back answer using EOL_TYPE; globals EOL_DOS,
# EOL_UNIX, and EOL_MAC are also set
function getEOLtype()
{
   IFS=" "
   RESULTS=$(dos2unix -idum "$1")
   EOL_DOS=$(echo $RESULTS | cut -d " " -f 1)
   EOL_UNIX=$(echo $RESULTS | cut -d " " -f 2)
   EOL_MAC=$(echo $RESULTS | cut -d " " -f 3)

   if [ -z $EOL_DOS ] || [ -z $EOL_UNIX ] || [ -z $EOL_MAC ]; then
      echo "Could not get line ending count using 'dos2unix'. Aborting."
      exit
   fi

   if [ $EOL_DOS == "0" ] && [ $EOL_UNIX != "0" ] && [ $EOL_MAC == "0" ]; then
      EOL_TYPE=$TYPE_UNIX
   elif [ $EOL_DOS != "0" ] && [ $EOL_UNIX == "0" ] && [ $EOL_MAC == "0" ]; then
      EOL_TYPE=$TYPE_DOS
   elif [ $EOL_DOS == "0" ] && [ $EOL_UNIX == "0" ] && [ $EOL_MAC != "0" ]; then
      EOL_TYPE=$TYPE_MAC
   elif [ $EOL_DOS == "0" ] && [ $EOL_UNIX == "0" ] && [ $EOL_MAC == "0" ]; then
      EOL_TYPE=$TYPE_NONE
   else
      EOL_TYPE=$TYPE_MIX
   fi

   IFS="
"
}

# Print requested combination of file name and/or its EOL type
function printEOLtype()
{
   if [ "$1" == "name" ]; then
      echo $2
   elif [ "$1" == "type" ]; then
      if [ $EOL_TYPE -eq $TYPE_UNIX ]; then
         echo "This is a Unix (LF) file."
      elif [ $EOL_TYPE -eq $TYPE_DOS ]; then
         echo "This is a DOS (CR+LF) file."
      elif [ $EOL_TYPE -eq $TYPE_MAC ]; then
         echo "This is a Mac (CR) file."
      elif [ $EOL_TYPE -eq $TYPE_MIX ]; then
         echo "The line endings are mixed: DOS=$EOL_DOS, UNIX=$EOL_UNIX, MAC=$EOL_MAC."
      elif [ $EOL_TYPE -eq $TYPE_NONE ]; then
         echo "There are no line endings in this file!"
      else
         echo "Unhandled EOL type!"
      fi
   elif [ "$1" == "full" ]; then
      if [ $EOL_TYPE -eq $TYPE_UNIX ]; then
         echo -e "$2:\n\033[38;5;41mThis is a Unix (LF) file.\033[0m"
      elif [ $EOL_TYPE -eq $TYPE_DOS ]; then
         echo -e "$2:\n\033[38;5;117mThis is a DOS (CR+LF) file.\033[0m"
      elif [ $EOL_TYPE -eq $TYPE_MAC ]; then
         echo -e "$2:\n\033[38;5;169mThis is a Mac (CR) file.\033[0m"
      elif [ $EOL_TYPE -eq $TYPE_NONE ]; then
         echo -e "$2:\n${under}There are no line endings in this file!${norm}"
      elif [ $EOL_TYPE -eq $TYPE_MIX ]; then
         echo -e "$2:\n${bold}The line endings are mixed: DOS=$EOL_DOS, UNIX=$EOL_UNIX, MAC=$EOL_MAC.${norm}"
      fi
   else
      echo "Unknown argument to printEOLtype()!"
   fi
}

# Get results from getEOLtype(), print to screen if appropriate, and add to tallies
function getEOLPrintAndTally()
{
   printed=1
   getEOLtype "$1" # this sets EOL_TYPE
   if [ $EOL_TYPE -eq $PRINT_TYPE ]; then
      printEOLtype name "$FILE"
   elif [ $PRINT_TYPE -eq $TYPE_ALL ]; then
      printEOLtype full "$FILE"
   else
      printed=0
   fi
   if [ $EOL_TYPE -eq $TYPE_UNIX ]; then
      let UNIX_COUNT+=1
   elif [ $EOL_TYPE -eq $TYPE_DOS ]; then
      let DOS_COUNT+=1
   elif [ $EOL_TYPE -eq $TYPE_MAC ]; then
      let MAC_COUNT+=1
   elif [ $EOL_TYPE -eq $TYPE_MIX ]; then
      let MIX_COUNT+=1
   elif [ $EOL_TYPE -eq $TYPE_NONE ]; then
      let NONE_COUNT+=1
   else
      printed=0
   fi

   let PRINT_TOTAL+=$printed
}

# Evaluate EOL type with getEOLtype(), convert if appropriate
function setEOL()
{
   converted=0
   getEOLtype "$1" # this sets EOL_TYPE

   # If we're in single-file operation mode, there was no from-type supplied by the user, so here's a
   # hack to fix that
   if [ $TARGET_TYPE -eq $TARGET_FILE ]; then
      FROM_TYPE=$EOL_TYPE
   fi

   if [ $FROM_TYPE -eq $TO_TYPE ]; then
      # Do nothing, but advise the user if we're in single-file mode
      if [ $TARGET_TYPE -eq $TARGET_FILE ]; then
         echo "File is already of this type!"
      fi
   elif [ $EOL_TYPE -eq $FROM_TYPE ]; then
      if [ $FROM_TYPE -eq $TYPE_UNIX ] && [ $TO_TYPE -eq $TYPE_DOS ]; then
         unix2dos "$1"
         converted=1
      elif [ $FROM_TYPE -eq $TYPE_DOS ] && [ $TO_TYPE -eq $TYPE_UNIX ]; then
         dos2unix "$1"
         converted=1
      elif [ $FROM_TYPE -eq $TYPE_UNIX ] && [ $TO_TYPE -eq $TYPE_MAC ]; then
         unix2mac "$1"
         converted=1
      elif [ $FROM_TYPE -eq $TYPE_MAC ] && [ $TO_TYPE -eq $TYPE_UNIX ]; then
         mac2unix "$1"
         converted=1
      elif [ $FROM_TYPE -eq $TYPE_MAC ] && [ $TO_TYPE -eq $TYPE_DOS ]; then
         # 'mac2dos' is not a thing, so first convert Mac EOLs to Unix EOLs, placing in a
         # temp file since we can't convert it in place, then replace orig file with temp
         # file in Unix format and convert that
         TEMP_FILE=$(mktemp)
         LC_ALL=C tr '\r' '\n' < "$1" > "$TEMP_FILE" # CR -> LF
         rm "$1"
         mv "$TEMP_FILE" "$1"
         unix2dos "$1" # LF -> CR+LF
         converted=1
      elif [ $FROM_TYPE -eq $TYPE_DOS ] && [ $TO_TYPE -eq $TYPE_MAC ]; then
         # 'dos2mac' is not a thing, so first convert DOS EOLs to Unix EOLs, placing in a
         # temp file since we can't convert it in place, then replace orig file with temp
         # file in Unix format and convert that
         TEMP_FILE=$(mktemp)
         LC_ALL=C tr -d '\r' < "$1" > "$TEMP_FILE" # CR+LF -> LF
         rm "$1"
         mv "$TEMP_FILE" "$1"
         unix2mac "$1" # LF -> CR
         converted=1
      else
         echo "Unhandled conversion. Something slipped through the cracks somehow! Aborting."
         exit
      fi
   fi

   let CONVERT_TOTAL+=$converted
}


## ARGUMENT PROCESSING ##
# Check for too few arguments
if [ "$#" -lt 2 ]; then
   helpAndExit
fi

# Process all arguments
while (( "$#" )); do
   # Shift 2 spaces unless that takes us past end of argument array, which seems to hang the shell
   SAFE_SHIFT=2
   if [ "$#" -eq 1 ]; then
      SAFE_SHIFT=1
   fi

   case "$1" in
      --get )        OPER_MODE=$MODE_GET; TARGET_ARG="$2"; shift $SAFE_SHIFT;;
      --change )     OPER_MODE=$MODE_SET; TARGET_ARG="$2"; shift $SAFE_SHIFT;;
      --list )       PRINT_ARG="$2"; shift $SAFE_SHIFT;;
      --only )       FOR_ARG="$2"; shift $SAFE_SHIFT;;
      --from )       FROM_ARG="$2"; shift $SAFE_SHIFT;;
      --to )         TO_ARG="$2"; shift $SAFE_SHIFT;;
      --show-skips ) SHOW_SKIPS=1; shift;;
      * )            echo "Unrecognized argument '$1'. Aborting."; helpAndExit;;
   esac
done

# Get operation mode
if [ $OPER_MODE -eq 0 ]; then
   echo "You failed to pick a mode of operation ('--get' or '--change'). Aborting."
   exit
fi

# Verify target
if [ -z "$TARGET_ARG" ]; then
   echo "You failed to supply a path to a file or folder after '--get' or '--change'. Aborting."
   exit
else
   if [ -d "$TARGET_ARG" ]; then
      TARGET_TYPE=$TARGET_DIR
   elif [ -f "$TARGET_ARG" ]; then
      TARGET_TYPE=$TARGET_FILE
   else
      echo "There is no file or folder at the path \"$TARGET_ARG\". Aborting."
      exit
   fi
fi

# Get type of file to show
if [ ! -z "$PRINT_ARG" ]; then
   if [ $OPER_MODE -ne $MODE_GET ] || [ $TARGET_TYPE -ne $TARGET_DIR ]; then
      echo "You can't use '--list' except with \"--get [dir]\". Aborting."
      exit
   fi
   PRINT_ARG=$(echo $PRINT_ARG | awk '{ print tolower($0) }')
   if [ $PRINT_ARG == "unix" ]; then
      PRINT_TYPE=$TYPE_UNIX
   elif [ $PRINT_ARG == "dos" ]; then
      PRINT_TYPE=$TYPE_DOS
   elif [ $PRINT_ARG == "mac" ]; then
      PRINT_TYPE=$TYPE_MAC
   elif [ $PRINT_ARG == "mixed" ]; then
      PRINT_TYPE=$TYPE_MIX
   elif [ $PRINT_ARG == "none" ]; then
      PRINT_TYPE=$TYPE_NONE
   elif [ $PRINT_ARG == "all" ]; then
      PRINT_TYPE=$TYPE_ALL
   else
      echo "You failed to supply a valid line ending type. Aborting."
      helpAndExit
   fi
else
   if [ -z "$FOR_ARG" ]; then
      PRINT_TYPE=$TYPE_ALL
   fi
fi

# Get suffix filter
if [ ! -z "$FOR_ARG" ]; then
   if [ $TARGET_TYPE -ne $TARGET_DIR ]; then
      echo "You can't use '--only' except with \"--get [dir]\" or \"--change [dir]\". Aborting."
      exit
   fi
   IFS=" "
   SUFFIXES=($FOR_ARG)
   IFS="
"
fi

# Get change-from type
if [ ! -z $FROM_ARG ]; then
   if [ $OPER_MODE -ne $MODE_SET ]; then
      echo "You cannot use the '--from' argument unless you are using '--change'. Aborting."
      exit
   fi
   if [ $TARGET_TYPE -ne $TARGET_DIR ]; then
      mypr "You cannot use the '--from' argument unless you are supply a directory with '--change'. When altering a single file, it will be converted regardless of its initial type. Aborting."
      exit
   fi
   FROM_ARG=$(echo $FROM_ARG | awk '{ print tolower($0) }')
   if [ $FROM_ARG == "unix" ]; then
      FROM_TYPE=$TYPE_UNIX
   elif [ $FROM_ARG == "dos" ]; then
      FROM_TYPE=$TYPE_DOS
   elif [ $FROM_ARG == "mac" ]; then
      FROM_TYPE=$TYPE_MAC
   else
      echo "Unrecognized parameter \"$FROM_ARG\" supplied with '--from' argument. Aborting."
      helpAndExit
   fi
else
   if [ $OPER_MODE -eq $MODE_SET ] && [ $TARGET_TYPE -eq $TARGET_DIR ]; then
      echo "You must use the '--from' argument with \"--change [dir]\". Aborting."
      exit
   fi
fi

# Get change-to type
if [ ! -z $TO_ARG ]; then
   if [ $OPER_MODE -ne $MODE_SET ]; then
      mypr "You cannot use the '--to' argument unless you are using '--change'. Aborting."
      exit
   fi
   TO_ARG=$(echo $TO_ARG | awk '{ print tolower($0) }')
   if [ $TO_ARG == "unix" ]; then
      TO_TYPE=$TYPE_UNIX
   elif [ $TO_ARG == "dos" ]; then
      TO_TYPE=$TYPE_DOS
   elif [ $TO_ARG == "mac" ]; then
      TO_TYPE=$TYPE_MAC
   else
      echo "Unrecognized parameter \"$TO_ARG\" supplied with '--to' argument. Aborting."
      helpAndExit
   fi
else
   if [ $OPER_MODE -eq $MODE_SET ]; then
      echo "You must use the '--to' argument with '--change'. Aborting."
      exit
   fi
fi

# In mass-change mode, make sure that from- and to-types are the same
if [ $OPER_MODE -eq $MODE_SET ]; then
   if [ $TARGET_TYPE -eq $TARGET_DIR ] && [ $TO_TYPE -eq $FROM_TYPE ]; then
      echo "You specified the same EOL type to look for as to convert to! Aborting."
      exit
   fi
fi

# '--show-skips' won't have any effect when '--only' is in use, so don't let the user think it's working
if [ $SHOW_SKIPS -eq 1 ] && [ ! -z "$FOR_ARG" ]; then
   mypr "You cannot use '--show-skips' when also supplying suffixes with '--only', as '--only' forces EOL Manager to look at all files matching that suffix and nothing will be skipped."
   exit
fi


## MAIN SCRIPT ##
if [ $TARGET_TYPE -eq $TARGET_DIR ]; then # directory operation
   if [ ! -z "$FOR_ARG" ]; then # suffix filter mode
      GRAND_TOTAL=0
      for SUFFIX in ${SUFFIXES[@]}; do
         TYPE_FOUND=0
         TYPE_CONVERTED=0
         MAC_COUNT=0
         DOS_COUNT=0
         UNIX_COUNT=0
         MIX_COUNT=0
         NONE_COUNT=0
         NUM_TYPES=0
         for FILE in `find -s "$TARGET_ARG" -type f | grep "\.${SUFFIX}$"`; do
            let TYPE_FOUND+=1
            if [ $OPER_MODE -eq $MODE_GET ]; then
               #MUTE_THIS=$(getEOLPrintAndTally "$FILE")
               getEOLPrintAndTally "$FILE"
            else # set mode
               LAST_CONVERT_TOTAL=$CONVERT_TOTAL
               MUTE_THIS=$(setEOL "$FILE")
               if [ $CONVERT_TOTAL -gt $LAST_CONVERT_TOTAL ]; then
                  let TYPE_CONVERTED+=1
               fi
            fi # end "if get/set" main loop
         done # end file loop

         # In get mode, print our findings
         if [ $OPER_MODE -eq $MODE_GET ]; then
            # Grammar check
            STR_FILES="files"
            if [ $TYPE_FOUND -eq 1 ]; then
               STR_FILES="file"
            fi

            # Count number of line ending types found
            if [ $MAC_COUNT -gt 0 ]; then
               let NUM_TYPES+=1
            fi
            if [ $DOS_COUNT -gt 0 ]; then
               let NUM_TYPES+=1
            fi
            if [ $UNIX_COUNT -gt 0 ]; then
               let NUM_TYPES+=1
            fi
            if [ $NONE_COUNT -gt 0 ]; then
               let NUM_TYPES+=1
            fi
            if [ $MIX_COUNT -gt 0 ]; then
               let NUM_TYPES+=1
            fi

            # Output results
            if [ $TYPE_FOUND -gt 0 ]; then
               echo -n "Found $TYPE_FOUND .$SUFFIX $STR_FILES with these endings: "
               if [ $UNIX_COUNT -gt 0 ]; then
                  echo -n "Unix ($UNIX_COUNT)"
                  let NUM_TYPES-=1
                  if [ $NUM_TYPES -gt 0 ]; then
                     echo -n ", "
                  fi
               fi
               if [ $DOS_COUNT -gt 0 ]; then
                  echo -n "DOS ($DOS_COUNT)"
                  let NUM_TYPES-=1
                  if [ $NUM_TYPES -gt 0 ]; then
                     echo -n ", "
                  fi
               fi
               if [ $MAC_COUNT -gt 0 ]; then
                  echo -n "Mac ($MAC_COUNT)"
                  let NUM_TYPES-=1
                  if [ $NUM_TYPES -gt 0 ]; then
                     echo -n ", "
                  fi
               fi
               if [ $MIX_COUNT -gt 0 ]; then
                  echo -n "mixed ($MIX_COUNT)"
                  let NUM_TYPES-=1
                  if [ $NUM_TYPES -gt 0 ]; then
                     echo -n ", "
                  fi
               fi
               if [ $NONE_COUNT -gt 0 ]; then
                  echo -n "none ($NONE_COUNT)"
                  let NUM_TYPES-=1
               fi
               echo "."
            else
               echo "No .$SUFFIX $STR_FILES were found."
            fi
         else # set mode reporting
            STR_FILES="files"
            if [ $TYPE_FOUND -eq 1 ]; then
               STR_FILES="file"
            fi

            echo "Considered $TYPE_FOUND .$SUFFIX $STR_FILES, converted $TYPE_CONVERTED."
         fi # end "if get/set" reporting

         let GRAND_TOTAL+=TYPE_FOUND
      done # end suffix loop

      STR_FILES="files"
      if [ $GRAND_TOTAL -eq 1 ]; then
         STR_FILES="file"
      fi
      if [ $OPER_MODE -eq $MODE_GET ]; then
         echo "Considered a total of $GRAND_TOTAL $STR_FILES."
      else
         echo "Considered a total of $GRAND_TOTAL $STR_FILES, and converted $CONVERT_TOTAL."
      fi
   else # no suffix filter
      for FILE in `find -s "$TARGET_ARG" -type f`; do
         # Check with 'file' if this is text before proceeding; we don't do this if the user supplied
         # suffixes for us because we assume that he knows what he's doing
         RESULTS=$(file "$FILE" | grep ":.*text")
         RESULT_CHARS=$(echo -n "$RESULTS" | wc -c)
         if [ $RESULT_CHARS -gt 1 ]; then
            if [ $OPER_MODE -eq $MODE_GET ]; then
               getEOLPrintAndTally "$FILE"
            else # set mode
               setEOL "$FILE"
            fi
         elif [ $SHOW_SKIPS -eq 1 ] && [[ ! "$FILE" =~ \.DS_Store ]]; then
            echo "Skipping non-text file $FILE..."
         fi
      done # end file loop

      STR_FILES="files"
      if [ $OPER_MODE -eq $MODE_GET ]; then
         if [ $PRINT_TOTAL -eq 1 ]; then
            STR_FILES="file"
         fi
         echo "Found $PRINT_TOTAL $STR_FILES."
      else
         if [ $CONVERT_TOTAL -eq 1 ]; then
            STR_FILES="file"
         fi
         echo "Converted $CONVERT_TOTAL $STR_FILES."
      fi
   fi # end "if suffix/no-suffix mode"
else # file operation
   if [ $OPER_MODE -eq $MODE_GET ]; then
      getEOLtype "$TARGET_ARG"
      printEOLtype type "$TARGET_ARG"
   else # set mode
      MUTE_THIS=$(setEOL "$TARGET_ARG")
   fi
fi # end "if directory/file"