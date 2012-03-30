#!/usr/bin/env bash

USER_AGENT='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.874.54 Safari/535.2'
USERID=$1
MYDIR=`pwd`
DIR=$MYDIR/$2
DOWNLOADED_BY=$3
VERSION=$4
CACHE=$MYDIR/cache/$USERID
WGET_WARC=$MYDIR/wget-warc
WARC2WARC=$MYDIR/warc2warc.py

mkdir -p $CACHE

# Note: the warc2warc bit decompresses improperly compressed CSS from
# b.fanfiction.net.  warc2warc -D also removes chunking, which isn't strictly
# necessary, but doesn't seem to be that harmful.
set -x
cd $CACHE && \
$WGET_WARC \
	-U "$USER_AGENT" \
	-o "$DIR/$USERID.log" \
	-e robots=off \
	--warc-file="$DIR/$USERID" \
	--warc-max-size=inf \
	--warc-header='operator: Archive Team' \
	--warc-header="username: $DOWNLOADED_BY" \
	--warc-header="ffgrab-version: $VERSION" \
	-nv -np -nd \
	--no-remove-listing \
	--no-timestamping \
	--trust-server-names \
	--page-requisites \
	--span-hosts \
	-i "$DIR/$USERID.txt" && \
cd - && rm -rf $CACHE && \
$WARC2WARC -Z -D $DIR/$USERID.warc.gz > $DIR/$USERID.cooked.warc.gz

set +x
