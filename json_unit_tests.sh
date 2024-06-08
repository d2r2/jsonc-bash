#!/bin/bash

#
# MIT License
#
# Copyright (c) 2021-2024 Denis Dyakov <denis.dyakov@gma**.com>
#
# Inspired by minimalistic JSON parser written
# by Serge Zaitsev: https://github.com/zserge/jsmn.
# This code can be considered rewritten from
# the original project with some modifications.
#
# Support parsing of regular JSON, as well as JSONC (JSON with comments).
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
{
  "menu": {
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
  }
}
	EOF
}


# Function return regular JSONC sample with
# no error, to test error handling.
get_json_struct_with_no_error_3() {
	cat <<-EOF
{
	// Set CPU governor and frequencies range.
	// Use utility cpufreq-info and cpufreq-set. 
	"cpu": {
		"governor": "powersave",
		//"governor": "schedutil",
		"frequency": { "min": 408000, "max": 816000 }
	}
}
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

# Function return regular JSON sample with error
# on purpuse, to test error handling.
# Comma is missing
get_json_struct_with_error_7() {
	cat <<-EOF
{"menu": {
  "id": "file",
  "type": "Word document",
  "popup": {
    "menuitem": [
      {"value": "Close", "onclick": "CloseDoc"}
    ],
  }
  "system": {
    "custom_scripts": [
      "fail2ban-mqtt"
    ]
  }
  }}
	EOF
}

# Function return regular JSON sample with error
# on purpuse, to test error handling.
# Comma is missing
get_json_struct_with_error_8() {
	cat <<-EOF
{"menu": {
  "id": "file",
  "type": "Word document",
  "popup": {
    "menuitem": [
      {"value": "Close", "onclick": "CloseDoc"}
    ]
  }
  {"value2": "Close", "onclick2": "CloseDoc"}
  }}
	EOF
}

join_str() {
  local separator="$1"
  shift
  local first="$1"
  shift
  printf "%s" "$first" "${@/#/$separator}"
}

print_val() {
  local val="$1"
  [[ "$val" == "" ]] && echo -n "<empty>" || echo -n "$val"
}

run_tests() {
  # Test 10
  # Unit test. Parse JSON/JSONC with no error
  local test_no="10"
  parse_json_from_pipe < <(get_json_struct_with_no_error_1); local status=$?
  if [[ $status -eq 0 ]]; then
    echo "Test #${test_no} PASSED. Success status=$status. No error parsing JSON/JSONC" 1>&2
  else
    echo "Test #${test_no} FAILED!!! Success status=$status. Report to developer or fix youself (and report to developer)!!!"
    exit 1
  fi
  #local xpath=("menu" "id" "menuitem" "0" "args" 2)
  #local val; get_json_path_value "val" ${xpath[@]}; local status=$?  
  #print_json_tokens

  #exit

  # Test 11
  # Unit test. Parse JSON/JSONC with no error
  test_no="11"
  parse_json_from_pipe < <(get_json_struct_with_no_error_2); local status=$?
  if [[ $status -eq 0 ]]; then
    echo "Test #${test_no} PASSED. Success status=$status. No error parsing JSON/JSONC" 1>&2
  else
    echo "Test #${test_no} FAILED!!! Success status=$status. Report to developer or fix youself (and report to developer)!!!"
    exit 1
  fi

  # Test 20
  # Unit test. Parse JSON/JSONC with no error and get value from XPath search
  test_no="20"
  parse_json_from_pipe < <(get_json_struct_with_no_error_2); local status=$?
  if [[ $status -eq 0 ]]; then
    echo "Test #${test_no} PASSED. Success status=$status. No error parsing JSON/JSONC" 1>&2
    # Test 21
    # Search value for valid path
    test_no="21"
    local xpath=("menu" "popup" "menuitem" "0" "args" 2)
    local val; get_json_path_value "val" ${xpath[@]}; local status=$?
    local expected_val="3.1415926"
    if [[ $status -eq 0 && "$val" == "$expected_val" ]]; then
      echo "Test #${test_no} PASSED. Success status=$status. Result=$(print_val $val). Expected value for $(join_str "/" ${xpath[@]})=$expected_val" 1>&2
    else
      echo "Test #${test_no} FAILED!!! Success status=$status. Result=$(print_val $val). Report to developer or fix youself (and report to developer)!!!"
    fi
    # Test 22
    # Search value for not matching upper/lower case, bu still valid path (nevertheless it should work)
    test_no="22"
    local xpath=("Menu" "popuP" "menUitem" "0" "ARgs" 3)
    local val; get_json_path_value "val" ${xpath[@]}; local status=$?
    local expected_val="И"
    if [[ $status -eq 0 && "$val" == "И" ]]; then
      echo "Test #${test_no} PASSED. Success status=$status. Result=$(print_val $val). Expected value for $(join_str "/" ${xpath[@]})=$expected_val" 1>&2
    else
      echo "Test #${test_no} FAILED!!! Success status=$status. Result=$(print_val $val). Report to developer or fix youself (and report to developer)!!!"
    fi
    # Test 23
    # Search value for invalid path (exceeding array size)
    test_no="23"
    local xpath=("menu" "popup" "menuitem" "0" "args" 4)
    local val; get_json_path_value "val" ${xpath[@]}; local status=$?
    if [[ $status -ne 0 ]]; then
      echo "Test #${test_no} PASSED. Success status=$status. Result=$(print_val $val). Value for $(join_str "/" ${xpath[@]}) is not found" 1>&2
    else
      echo "Test #${test_no} FAILED!!! Success status=$status. Result=$(print_val $val). Report to developer or fix youself (and report to developer)!!!"
    fi
    # Test 24
    # Search value for invalid path (menu-item and menuitem doesn't match)
    test_no="24"
    local xpath=("menu" "popup" "menu-item" "0" "args" 1)
    local val; get_json_path_value "val" ${xpath[@]}; local status=$?
    if [[ $status -ne 0 ]]; then
      echo "Test #${test_no} PASSED. Success status=$status. Result=$(print_val $val). Value for $(join_str "/" ${xpath[@]}) is not found" 1>&2
    else
      echo "Test #${test_no} FAILED!!! Success status=$status. Result=$(print_val $val) Report to developer or fix youself (and report to developer)!!!"
    fi
    # Test 25
    # Search for invalid path, and verify that $val is reassigned to empty value
    test_no="25"
    local xpath=("menu1" "popup" "menu-item" "0" "args" 1)
    local val="asdasd"; get_json_path_value "val" ${xpath[@]}; local status=$?
    local expected_val=""
    if [[ $status -ne 0 && "$val" == "$expected_val" ]]; then
      echo "Test #${test_no} PASSED. Success status=$status. Result=$(print_val $val). Expected value for $(join_str "/" ${xpath[@]})=$(print_val $expected_val)" 1>&2
    else
      echo "Test #${test_no} FAILED!!! Success status=$status. Result=$(print_val $val). Report to developer or fix youself (and report to developer)!!!"
    fi
  else
    echo "Test #${test_no} FAILED!!! Success status=$status. Result=$(print_val $val). Report to developer or fix youself (and report to developer)!!!"
    exit 1
  fi

  # Test 30
  # Unit test. Parse JSON/JSONC with no error and get value from XPath search
  test_no="30"
  parse_json_from_pipe < <(get_json_struct_with_no_error_3); local status=$?
  if [[ $status -eq 0 ]]; then
    echo "Test #${test_no} PASSED. Success status=$status. No error parsing JSON/JSONC" 1>&2
    # Test 31
    # Search value for valid path
    test_no="31"
    local xpath=("cpu" "governor")
    local val; get_json_path_value "val" ${xpath[@]}; local status=$?
    local expected_val="powersave"
    if [[ $status -eq 0 && "$val" == "$expected_val" ]]; then
      echo "Test #${test_no} PASSED. Success status=$status. Result=$(print_val $val). Expected value for $(join_str "/" ${xpath[@]})=$expected_val" 1>&2
    else
      echo "Test #${test_no} FAILED!!! Success status=$status. Result=$(print_val $val). Report to developer or fix youself (and report to developer)!!!"
    fi
    # Test 32
    # Search value for valid path
    test_no="32"
    local xpath=("cpu" "frequency" "min")
    local val; get_json_path_value "val" ${xpath[@]}; local status=$?
    local expected_val="408000"
    if [[ $status -eq 0 && "$val" == "$expected_val" ]]; then
      echo "Test #${test_no} PASSED. Success status=$status. Result=$(print_val $val). Expected value for $(join_str "/" ${xpath[@]})=$expected_val" 1>&2
    else
      echo "Test #${test_no} FAILED!!! Success status=$status. Result=$(print_val $val). Report to developer or fix youself (and report to developer)!!!"
    fi
    # Test 33
    # Search value for valid path
    test_no="33"
    local xpath=("cpu" "frequency" "max")
    local val; get_json_path_value "val" ${xpath[@]}; local status=$?
    local expected_val="816000"
    if [[ $status -eq 0 && "$val" == "$expected_val" ]]; then
      echo "Test #${test_no} PASSED. Success status=$status. Result=$(print_val $val). Expected value for $(join_str "/" ${xpath[@]})=$expected_val" 1>&2
    else
      echo "Test #${test_no} FAILED!!! Success status=$status. Result=$(print_val $val). Report to developer or fix youself (and report to developer)!!!"
    fi
fi

  # Test 50
  # Unit test. Parse JSON/JSONC with error on purpose
  test_no="50"
  parse_json_from_pipe < <(get_json_struct_with_error_1); local status=$?
  if [[ $status -ne 0 ]]; then
    echo "Test #${test_no} PASSED. Success status=$status. Error parsing JSON/JSONC in line $JSON_LINE_ERROR" 1>&2
  else
    echo "Test #${test_no} FAILED!!! Success status=$status. Report to developer or fix youself (and report to developer)!!!"
    exit 1
  fi

  # Test 51
  # Unit test. Parse JSON/JSONC with error on purpose
  test_no="51"
  parse_json_from_pipe < <(get_json_struct_with_error_2); local status=$?
  if [[ $status -ne 0 ]]; then
    echo "Test #${test_no} PASSED. Success status=$status. Error parsing JSON/JSONC in line $JSON_LINE_ERROR" 1>&2
  else
    echo "Test #${test_no} FAILED!!! Success status=$status. Report to developer or fix youself (and report to developer)!!!"
    exit 1
  fi

  # Test 52
  # Unit test. Parse JSON/JSONC with error on purpose
  test_no="52"
  parse_json_from_pipe < <(get_json_struct_with_error_3); local status=$?
  if [[ $status -ne 0 ]]; then
    echo "Test #${test_no} PASSED. Success status=$status. Error parsing JSON/JSONC in line $JSON_LINE_ERROR" 1>&2
  else
    echo "Test #${test_no} FAILED!!! Success status=$status. Report to developer or fix youself (and report to developer)!!!"
    exit 1
  fi

  # Test 53
  # Unit test. Parse JSON/JSONC with error on purpose
  test_no="53"
  parse_json_from_pipe < <(get_json_struct_with_error_4); local status=$?
  if [[ $status -ne 0 ]]; then
    echo "Test #${test_no} PASSED. Success status=$status. Error parsing JSON/JSONC in line $JSON_LINE_ERROR" 1>&2
  else
    echo "Test #${test_no} FAILED!!! Success status=$status. Report to developer or fix youself (and report to developer)!!!"
    exit 1
  fi

  # Test 54
  # Unit test. Parse JSON/JSONC with error on purpose
  test_no="54"
  parse_json_from_pipe < <(get_json_struct_with_error_5); local status=$?
  if [[ $status -ne 0 ]]; then
    echo "Test #${test_no} PASSED. Success status=$status. Error parsing JSON/JSONC in line $JSON_LINE_ERROR" 1>&2
  else
    echo "Test #${test_no} FAILED!!! Success status=$status. Report to developer or fix youself (and report to developer)!!!"
    exit 1
  fi

  # Test 55
  # Unit test. Parse JSON/JSONC with error on purpose
  test_no="55"
  parse_json_from_pipe < <(get_json_struct_with_error_6); local status=$?
  if [[ $status -ne 0 ]]; then
    echo "Test #${test_no} PASSED. Success status=$status. Error parsing JSON/JSONC in line $JSON_LINE_ERROR" 1>&2
  else
    echo "Test #${test_no} FAILED!!! Success status=$status. Report to developer or fix youself (and report to developer)!!!"
    exit 1
  fi

  # Test 56
  # Unit test. Parse JSON/JSONC with error on purpose
  test_no="56"
  parse_json_from_pipe < <(get_json_struct_with_error_7); local status=$?
  #print_json_tokens
  if [[ $status -ne 0 ]]; then
    echo "Test #${test_no} PASSED. Success status=$status. Error parsing JSON/JSONC in line $JSON_LINE_ERROR" 1>&2
  else
    echo "Test #${test_no} FAILED!!! Success status=$status. Report to developer or fix youself (and report to developer)!!!"
    exit 1
  fi

  # Test 57
  # Unit test. Parse JSON/JSONC with error on purpose
  test_no="57"
  parse_json_from_pipe < <(get_json_struct_with_error_8); local status=$?
  #print_json_tokens
  if [[ $status -ne 0 ]]; then
    echo "Test #${test_no} PASSED. Success status=$status. Error parsing JSON/JSONC in line $JSON_LINE_ERROR" 1>&2
  else
    echo "Test #${test_no} FAILED!!! Success status=$status. Report to developer or fix youself (and report to developer)!!!"
    exit 1
  fi
}

JSON_WARN_INVALID_PATH_INDEX=0 # disable WARNING report on invalid XPath search array index
run_tests
