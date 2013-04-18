#!/usr/bin/env bash

#
# Different ways to check some or all files in the project for
# syntax errors
#

function process_working_tree_files {
    local file_source=$1
    local executor=$2
    numfiles=$(eval "$file_source | wc -l")
    echo "($numfiles files)"
    eval "$file_source | $executor $CHECKER | grep -v 'Syntax OK'"
    if [ $? -eq 0 ]; then
	ERROR=true
    fi
}

function process_staged_files {
    # necessary check for initial commit
    if git rev-parse --verify HEAD >/dev/null 2>&1
    then
	against=HEAD
    else
	# Initial commit: diff against an empty tree object
	against=4b825dc642cb6eb9a060e54bf8d69288fbee4904
    fi

    # Set field separator to new line
    IFS='
'

    # get a list of staged files and check contents
    for line in $(git diff-index --cached --full-index $against); do
	# split needed values
	sha=$(echo $line | cut -d' ' -f4)
	temp=$(echo $line | cut -d' ' -f5)
	status=$(echo $temp | cut -d' ' -f1)
	filename=$(echo $temp | cut -d'	' -f2)

	# file extension
	ext=$(echo $filename | sed 's/^.*\.//')

	# only check ruby files
	if [ $ext != "rb" ]; then
	    continue
	fi

	# do not check deleted files
	if [ $status = "D" ]; then
	    continue
	fi

	# check the staged file content for syntax errors
	result=$(eval "git cat-file -p $sha | $CHECKER")
	if [ $? -ne 0 ]; then
            echo "$filename :"
	    ERROR=true
	    # Swap back in correct filenames
	    errors=$(echo "$errors"; echo "$result" | sed -e "s@-:@@")
	fi
    done
    unset IFS

    if $ERROR; then
	echo "$errors"
    fi
}

#
# Main program
#

ERROR=false
STAGED_ONLY=false
CHECKER="ruby -c 2>&1"

echo "Ruby syntax check:"

if [ "$1" != "" ]; then
    if [ "$1" == "-c" ]; then
	FILE_SOURCE="git diff --name-only | grep '.*\.rb\$'"
	EXECUTOR="xargs -n 1"

	echo "checking files with unstaged changes:"
	eval $FILE_SOURCE
    else
	if [ "$1" == "-s" ]; then
	    echo "checking all staged files"
	    STAGED_ONLY=true
	else
	    echo "parameter error"
	    echo "supported parameters:"
	    echo "-c : to only check files with unstaged changes"
	    echo "-s : to only check staged files"
            echo " else check all files."
	    exit 1
	fi
    fi
else # default: check all files
    FILE_SOURCE="find ./[^.]* -name '*.rb'"
    echo "checking whole project in parallel mode"
    EXECUTOR="xargs -P 0 -n 1"
fi


echo "--"

if $STAGED_ONLY; then
    process_staged_files
else
    process_working_tree_files "$FILE_SOURCE" "$EXECUTOR"
fi

if $ERROR; then
    exit 1
else
    echo 'Syntax OK for all checked files'
    exit 0
fi
