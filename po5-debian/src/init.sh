#!/bin/sh -e
# initialization script for po5-debian9
# See the README file for details
# Copyright (c) 2019 Iuri Sampaio <iuri@iurix.com>
# This code is provided under the GNU GPL licenses.

set -e
# comment out to debug
#set -x

# ----------------------------------------------------------------------------------------------
# Script to initialize ]project-open[ V5.0 in a Docker image for CentOS 7
# ----------------------------------------------------------------------------------------------

PODATA=/var/lib/docker-projop

exec >> "$PODATA/runtime/init.log" 2>&1
echo "init: started at $(date -R)"

# initialize the persistent data directory if needed
if [ -e "$PODATA/runtime/.initialized" ] ; then
	echo "init: persistetd data already initialized"
else
	echo "init: initializing persistent data"
	tar -xzf "$PODATA/initial.tar.gz" -C "$PODATA/runtime"
fi

#
# Now run everything else provided by docker
#

if [ $# -gt 0 ] ; then
	echo "init: running the provided command $*"
	exec "$@"
else
	echo "init: running the default command /usr/sbin/init"
	exec /usr/sbin/init
fi

# if we get here then something went wrong
echo "init: ERROR"
exit 1

