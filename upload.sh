#!/usr/bin/env bash

SOURCE=$1
TARGET=$2

set -x
rsync -avR $SOURCE $TARGET
