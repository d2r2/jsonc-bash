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

# Function return regular JSON sample
get_json_struct() {
	cat <<-EOF
{"menu": {
  "id": "file",
  "type": "Word document",
  "popup": {
    "menuitem": [
      {"value": "New", "onclick": "CreateNewDoc", "args": [null, true, false, "\u042Fndex" ] },
      {"value": "Open", "onclick": "OpenDoc", "args": [1, "some text", 3.1415926] },
      {"value": "Close", "onclick": "CloseDoc"}
    ],
  },
}}
	EOF
}


echo "-----------------------------"
echo "Original JSON/JSONC to parse:"
echo "-----------------------------"
get_json_struct

parse_json_from_pipe < <(get_json_struct); retval=$?
if [[ $retval -ne 0 ]]; then
	echo "Error parsing JSON in line $JSON_LINE_ERROR" 1>&2
	exit 1
fi

# Uncomment next few lines for debug purpose
#echo "Print JSON parse result internals for debug purpose:"
#print_json_tokens

echo "----------------"
echo "Parsing results:"
echo "----------------"
get_json_path_value "val" "menu" "id"
echo "- Select menu/id value = \"$val\""
get_json_path_value "val" "menu" "type"
echo "- Select menu/type value = \"$val\""
get_json_path_value "val" "menu" "popup" "menuitem" 1 "args" 2
echo "- Select menu/popup/menuitem/1/args/2 value = \"$val\""
get_json_path_value "val" "menu" "popup" "menuitem" 0 "args" 3
echo "- Select menu/popup/menuitem/0/args/3 value with unicode = \"$val\""

echo "- Iterate parsed JSON array menu/popup/menuitem to reconstruct function to call:"
i=0
get_json_path_value "cnt" "menu" "popup" "menuitem"
while [[ $i -lt $cnt ]]; do
	get_json_path_value "item1" "menu" "popup" "menuitem" $i "value"
	get_json_path_value "item2" "menu" "popup" "menuitem" $i "onclick"
	j=0
	get_json_path_value "cargs" "menu" "popup" "menuitem" $i "args"
	args=""
	while [[ $j -lt $cargs ]]; do
		#get_json_path_index "index" "menu" "popup" "menuitem" $i "args" $j
		#echo "Item found at $index"
		if [[ $args == "" ]]; then
			get_json_path_value 'val' 'menu' 'popup' 'Menuitem' $i 'args' $j
			args="\"$val\""
		else
			get_json_path_value 'val' 'menu' 'popup' 'menuitem' $i 'args' $j
			args="$args, \"$val\""
		fi
		j=$(( $j+1 ))
	done
	echo -e "\t* value=$item1, func_to_call=$item2($args)"
	i=$(( $i+1 ))
done
