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
source ./json.sh

# Function return regular JSON sample with
# no error, to test error handling.
get_json_struct_with_no_error_1() {
	cat <<-EOF
{"menu": {
  "id": "file",
  "type": "Word document",
  "popup": {
    "menuitem": [
      {"value": "Open", "onclick": "OpenDoc", "args": [1, "some text", 3.1415926, "\u0418"] },
      {"value": "Close", "onclick": "CloseDoc"}
    ],
  },
}}
	EOF
}


# Function return regular JSONC sample with
# no error, to test error handling.
get_json_struct_with_no_error_2() {
	cat <<-EOF
{"menu": {
  // Put one line comment here
  "id": "file",
  "type": "Word document",
  "popup": {
    "menuitem": [
      {"value": "Open", "onclick": "OpenDoc", "args": [1, "some text", 3.1415926, "\u0418"] },
      /*
        And multiline comment here
      */
      {"value": "Close", "onclick": "CloseDoc"}
    ],
  },
}}
	EOF
}


# Function return regular JSON sample with error
# on purpuse, to test error handling.
# Line 3 has last string quote lost
get_json_struct_with_error_1() {
	cat <<-EOF
{"menu": {
  "id": "file",
  "type": "Word document,
  "popup": {
    "menuitem": [
      {"value": "Open", "onclick": "OpenDoc", "args": [1, "some text", 3.1415926] },
      {"value": "Close", "onclick": "CloseDoc"}
    ],
  },
}}
	EOF
}


# Function return regular JSON sample with error
# on purpuse, to test error handling.
# Line 6 has invalid unicode char (contains not a hex value)
get_json_struct_with_error_2() {
	cat <<-EOF
{"menu": {
  "id": "file",
  "type": "Word document",
  "popup": {
    "menuitem": [
      {"value": "Open", "onclick": "OpenDoc", "args": [1, "some text", "\u041t"] },
      {"value": "Close", "onclick": "CloseDoc"}
    ],
  },
}}
	EOF
}

# Function return regular JSON sample with error
# on purpuse, to test error handling.
# Line 6 has invalid unicode char (only 3 hex codes, but must be 4)
get_json_struct_with_error_3() {
	cat <<-EOF
{"menu": {
  "id": "file",
  "type": "Word document",
  "popup": {
    "menuitem": [
      {"value": "Open", "onclick": "OpenDoc", "args": [1, "some text", "\u041"] },
      {"value": "Close", "onclick": "CloseDoc"}
    ],
  },
}}
	EOF
}

# Function return regular JSON sample with error
# on purpuse, to test error handling.
# Last line has closing bracket lost
get_json_struct_with_error_4() {
	cat <<-EOF
{"menu": {
  "id": "file",
  "type": "Word document",
  "popup": {
    "menuitem": [
      {"value": "Open", "onclick": "OpenDoc", "args": [1, "some text", "\u0418"] },
      {"value": "Close", "onclick": "CloseDoc"}
    ],
  },
}
	EOF
}

# Function return regular JSON sample with error
# on purpuse, to test error handling.
# Lost closing bracket in array in line 8
get_json_struct_with_error_5() {
	cat <<-EOF
{"menu": {
  "id": "file",
  "type": "Word document",
  "popup": {
    "menuitem": [
      {"value": "Open", "onclick": "OpenDoc", "args": [1, "some text", "\u0418"] },
      {"value": "Close", "onclick": "CloseDoc"}
  },
}}
	EOF
}

# Function return regular JSONC sample with error
# on purpuse, to test error handling.
# Unclosed multiline comment
get_json_struct_with_error_6() {
	cat <<-EOF
{"menu": {
  "id": "file",
  "type": "Word document",
  "popup": {
    "menuitem": [
      {"value": "Open", "onclick": "OpenDoc", "args": [1, "some text", "\u0418"] },
      /*
        Forget to close multiline comment
      {"value": "Close", "onclick": "CloseDoc"}
  },
}}
	EOF
}

# Unit test. Parse JSON with no error
parse_json_from_pipe < <(get_json_struct_with_no_error_1); retval=$?
if [[ $retval -eq 0 ]]; then
	echo "Test passed. No error parsing JSON" 1>&2
else
	echo "Test failed!!! Report to developer or fix youself (and report to developer)!!!"
	exit 1
fi

# Unit test. Parse JSON with no error
parse_json_from_pipe < <(get_json_struct_with_no_error_2); retval=$?
if [[ $retval -eq 0 ]]; then
	echo "Test passed. No error parsing JSON" 1>&2
else
	echo "Test failed!!! Report to developer or fix youself (and report to developer)!!!"
	exit 1
fi

# Unit test. Parse JSON with no error and search path value
parse_json_from_pipe < <(get_json_struct_with_no_error_2); retval=$?
if [[ $retval -eq 0 ]]; then
  # Search value
  val=$(get_json_path_value "menu" "popup" "menuitem" "0" "args" 2); retval=$?
  if [[ $retval -eq 0 && "$val" == "3.1415926" ]]; then
	  echo "Test passed. Value for menu/popup/menuitem/0/args/2 = $val" 1>&2
  else
	  echo "Test failed!!! Report to developer or fix youself (and report to developer)!!!"
  fi
  # Search value for not matching uppper/lower case path (nevertheless it should work)
  val=$(get_json_path_value "Menu" "popuP" "menUitem" "0" "ARgs" 3); retval=$?
  if [[ $retval -eq 0 && "$val" == "И" ]]; then
	  echo "Test passed. Value for Menu/popuP/menUitem/0/ARgs/3 = $val" 1>&2
  else
	  echo "Test failed!!! Report to developer or fix youself (and report to developer)!!!"
  fi
  # Search value for invalid path (exceeding array size)
  val=$(get_json_path_value "menu" "popup" "menuitem" "0" "args" 4); retval=$?
  if [[ $retval -ne 0 ]]; then
	  echo "Test passed. Value for menu/popup/menuitem/0/args/4 is not found" 1>&2
  else
	  echo "Test failed!!! Report to developer or fix youself (and report to developer)!!!"
  fi
  # Search value for invalid path (menu-item and menuitem doesn't match)
  val=$(get_json_path_value "menu" "popup" "menu-item" "0" "args" 1); retval=$?
  if [[ $retval -ne 0 ]]; then
	  echo "Test passed. Value for menu/popup/menu-item/0/args/1 is not found" 1>&2
  else
	  echo "Test failed!!! Report to developer or fix youself (and report to developer)!!!"
  fi
else
	echo "Test failed!!! Report to developer or fix youself (and report to developer)!!!"
	exit 1
fi

# Unit test. Parse JSON with error on purpose
parse_json_from_pipe < <(get_json_struct_with_error_1); retval=$?
if [[ $retval -ne 0 ]]; then
	echo "Test passed. Error parsing JSON in line $JSON_LINE_ERROR" 1>&2
else
	echo "Test failed!!! Report to developer or fix youself (and report to developer)!!!"
	exit 1
fi

# Unit test. Parse JSON with error on purpose
parse_json_from_pipe < <(get_json_struct_with_error_2); retval=$?
if [[ $retval -ne 0 ]]; then
	echo "Test passed. Error parsing JSON in line $JSON_LINE_ERROR" 1>&2
else
	echo "Test failed!!! Report to developer or fix youself (and report to developer)!!!"
	exit 1
fi

# Unit test. Parse JSON with error on purpose
parse_json_from_pipe < <(get_json_struct_with_error_3); retval=$?
if [[ $retval -ne 0 ]]; then
	echo "Test passed. Error parsing JSON in line $JSON_LINE_ERROR" 1>&2
else
	echo "Test failed!!! Report to developer or fix youself (and report to developer)!!!"
	exit 1
fi

# Unit test. Parse JSON with error on purpose
parse_json_from_pipe < <(get_json_struct_with_error_4); retval=$?
if [[ $retval -ne 0 ]]; then
	echo "Test passed. Error parsing JSON in line $JSON_LINE_ERROR" 1>&2
else
	echo "Test failed!!! Report to developer or fix youself (and report to developer)!!!"
	exit 1
fi

# Unit test. Parse JSON with error on purpose
parse_json_from_pipe < <(get_json_struct_with_error_5); retval=$?
if [[ $retval -ne 0 ]]; then
	echo "Test passed. Error parsing JSON in line $JSON_LINE_ERROR" 1>&2
else
	echo "Test failed!!! Report to developer or fix youself (and report to developer)!!!"
	exit 1
fi

# Unit test. Parse JSON with error on purpose
parse_json_from_pipe < <(get_json_struct_with_error_6); retval=$?
if [[ $retval -ne 0 ]]; then
	echo "Test passed. Error parsing JSON in line $JSON_LINE_ERROR" 1>&2
else
	echo "Test failed!!! Report to developer or fix youself (and report to developer)!!!"
	exit 1
fi
