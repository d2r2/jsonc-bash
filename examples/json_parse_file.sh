#!/bin/bash

#
# MIT License
#
# Copyright (c) 2021 Denis Dyakov <denis.dyakov@gma**.com>
#
# Inspired by minimalistic JSON parser written
# by Serge Zaitsev: https://github.com/zserge/jsmn.
# This code can be considered rewritten from
# the original project with some modifications.
#
# Support standard JSON, as well as its superset -
# JSONC (JSON with comments). Parsing comply with
# JSON standard and allow comments (JSONC extension).
#

# Load JSON library
source ../json.sh

if [ -z "$1" ]
then
      echo "Provide path to JSON file to parse. Exit now"
      exit 1
fi

parse_json "$1"; retval=$?
if [[ $retval -eq 0 ]]; then
    print_json_tokens
    :
fi
