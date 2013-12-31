#!/bin/bash

# find the location of this script file
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#echo $DIR

EXIT=0
# loop through all .sh files in the notify.d/ directory below this file's path
for i in "$DIR/notify.d/"*'.sh'; do
	#echo "running: $i" > /dev/stderr
	# run each one (respecting the scripts shebang...)
	eval $i > /dev/null
	if [ "$?" != '0' ]; then
		EXIT=1;
	fi
done

# if there was ever an error, then exit with one
exit $EXIT

