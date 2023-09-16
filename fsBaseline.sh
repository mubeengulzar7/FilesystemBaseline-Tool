#!/bin/bash
#
# Description:
# This program creates a file system baseline or if a previous baseline exists then compares the difference between the old and new bas# eline
# 
# Usage: ./fsBaseline.sh [ -d path ] <file1> [<file2>]
# -d Starting directory for baselining process 
# <file1> if only a single file is specified then a new baseline is created
# <file2> previous baseline file, to compare the difference
#
# 

function usageErr ()
{

	echo 'Usage: fsBaseline.sh [-d path] file1 [file2]'
	echo 'Creates or compares a baseline from path'
	echo 'Default for path is /'
	exit 2
} >&2

function dirhash ()
{
	find "${DIR[@]}" -type f | xargs -d '\n' sha1sum
}

# ===================================
# MAIN 	
# ===================================

declare -a DIR

# ---------- parse the arguments


while getopts "d:" MYOPT
do
	# no check for MYOPT since there is only one service
	DIR+=( "$OPTARG" )
done
shift $((OPTIND-1))

# no arguments? or too many?
(( $# == 0 || $# > 2 )) && usageErr

(( ${#DIR[*]} == 0 )) && DIR=( "/" )


# create either a baseline (only if 1 filename is provided)
# or a secondary summary (when two filename )


BASE="$1"
B2ND="$2"

if (( $# == 1 )) #only 1 arg
then 
	# create #BASE"
	dirhash > "$BASE"
	# all done for baseline
	exit
fi

if [[ ! -r  "$BASE" ]]
then
	usageErr 
fi


# If 2nd files, then compare the two
# else create/fill it

if [[ ! -e "$B2ND" ]]
then
	echo Creating "$B2ND"
	dirhash > "$B2ND"
fi

# Now we have: 2 files created by sha1sum 

declare -A  BYPATH BYHASH INUSE # assoc. arrays

# Load up the first file as the baseline

while read HNUM FN
do
	BYPATH["$FN"]=$HNUM
	BYHASH[$HNUM]="$FN"
	INUSE["$FN"]="X"
done < "$BASE"

# ---------- Now Begin the output
# See if each filename listed in the 2nd file is in
# the same place (path) as in the 1st (the baseline)

printf '<filesystem host="%s" dir="%s">\n' "$HOSTNAME" "${DIR[*]}"

while read HNUM FN
do
	WASHASH="${BYPATH[${FN}]}"
	# did it fine one? if not, it will be null 
	if [[ -z $WASHASH ]]
	then
		ALTFN="${BYHASH[$HNUM]}"
		if [[ -z $ALTFN ]]
		then
			printf ' <new>%s</new>\n' "$FN"
		else
			printf ' <relocated orig= "%s">%s</relocated>\n' "$ALTFN" "$FN" 
			INUSE["$ALTFN"]='_' # mark this as seen
		fi
	else
		INUSE["$FN"]='_' 	# mark this as seen
		if [[ $HNUM == $WASHASH ]]
		then
			continue;	# nothing changed 
		else
			printf ' <changed>%s</changed>\n' "$FN"
		fi
	fi
done < "$B2ND"

for FN in "${!INUSE[@]}"
do
	if  [[ "${INUSE[$FN]}" == 'X' ]]
	then
		printf ' <removed>%s</removed>\n' "$FN"	
	fi
done

printf '</filesystem>/n'
