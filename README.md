JSON/JSONC bash parser
======================

About
-----

Library `json.sh` allows you to parse JSON and JSONC (JSON superset with comments) formats in BASH and manipulate the parsed data to quickly select and search results.
This library does not claim to be high performance, but has been tested with JSON/JSONC configuration files on x86 and ARM Linux devices.

Features
--------

* compatible with standard JSON and unofficial JSONC formats
* no dependencies on any libraries (only standard BASH environment)
* incremental single-pass parsing
* library code is covered with unit-tests
* allow easily manipulate with parsed JSON data in BASH:
  * select values in XML XPath style
  * get JSON array size and index JSON array content

Compliance with the standard
----------------------------

There are a lot of discussions that JSON standard is not clearly defined in some parts over the years, and parsers may differ from each other in some tricky cases.
So I just put here briefly what supported and how:

* Objects and Arrays
* Strings (as keys and values):
  * Verify escaped characters
  * Verify escaped Unicode symbol structure (4 chars and all must be hex)
* Primitives:
  * Strictly defined that primitives should start as a number, true, false or null
* Permissive trailing commas: arrays and objects may contain commas (,) before closing brackets (]})
* C-style comments are allowed as JSONC extension:
  * One line comment starting with //
  * Multiline comments with /* */

Usage
-----

The parser itself is located in the file `json.sh`.

You can test parser from command line with the script `examples/json_parse_file.sh` to parse any JSON/JSONC file to get results (debug tokens output).

To embed the parser to your BASH decision, please, read explanation below.

Let's parse real JSON data:

``` json
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
```

First, load library in your BASH script:

``` bash
# Load json library
source ./json.sh
```

Then, try to parse JSON taken from file:

``` bash
parse_json "<path to json file>"; retval=$?
if [[ $retval -ne 0 ]]; then
	echo "Error parsing JSON in line $JSON_LINE_ERROR" 1>&2
	exit 1
fi
```

, either if we want to read JSON from pipe:

``` bash
parse_json_from_pipe < <(func_return_heredoc_with_json); retval=$?
if [[ $retval -ne 0 ]]; then
  echo "Error parsing JSON in line $JSON_LINE_ERROR" 1>&2
  exit 1
fi
```

In case of success, select parsing results. Get value with function `get_json_path_value` call, pointing search path via parameters:

``` bash
local val; get_json_path_value "val" "menu" "id"
echo "- Select menu/id value = $val"
local val; get_json_path_value "val" "menu" "type"
echo "- Select menu/type value = $val"
```

, with output:

```
- Select menu/id value = file
- Select menu/type value = Word document
```

Please note, that with `get_json_path_value` you can also index JSON arrays with integer values:

``` bash
local val; get_json_path_value "val" "menu" "popup" "menuitem" 1 "args" 2
echo "- Select menu/popup/menuitem/1/args/2 value = $val"
local val; get_json_path_value "val" "menu" "popup" "menuitem" 0 "args" 3
echo "- Select menu/popup/menuitem/0/args/3 value with unicode = $val"
```

, with output:

```
- Select menu/popup/menuitem/1/args/2 value = 3.1415926
- Select menu/popup/menuitem/0/args/3 value with unicode = Яndex
```

You can find additional usage demo in folder `examples` with BASH scripts: `parse_json_example1.sh`, `parse_json_example2.sh`, `json_parse_file.sh`.

API
---

API is limited to following recommended functions:

* `parse_json_from_pipe`: read and parse JSON taken from pipe.
  Return 0 in case of success, either non zero error code. In case of error `JSON_LINE_ERROR` variable pointing to the line where error found.
  > *Note*: You don't need to care about, but as a success parse result next internal variables filled with parsed information (tokens):
  > * `jt_type` - type (object, array, string, primitive)
  > * `jt_content` - content for strings and primitives
  > * `jt_parent` - reference to parent token
  > * `jt_size` - count of direct children subtrees in json structure
  > * `jt_size_tok` - total number of all child tokens

* `parse_json`: do the same as `parse_json_from_pipe`, but take data from file path passed via parameter.
* `get_json_path_value`: select JSON value with search path provided via parameters passed to the function from 2nd argument. Function return result to the variable which name specified in 1st argument. Can return JSON array size, if search path point to the array [...] in JSON document. The search path elements are compared with JSON key elements to find matches and it working in case insensitive mode.
* `print_json_tokens`: for debug purpose. Print the content of variables `jt_type`, `jt_content`, `jt_parent`, `jt_size`, `jt_size_tok` as a result of successful execution of `parse_json` either `parse_json_from_pipe` call.

Unit-tests
----------

You can run `json_unit_tests.sh` to verify that library is in working condition in your environment.
The output must contain only "`Test passed`" results, like this:

```
Test #20 PASSED. Success status=0. No error parsing JSON/JSONC
Test #21 PASSED. Success status=0. Result=3.1415926. Expected value for menu/popup/menuitem/0/args/2=3.1415926
...
Test #56 PASSED. Success status=2. Error parsing JSON/JSONC in line 9
Test #57 PASSED. Success status=1. Error parsing JSON/JSONC in line 9
```

In case of errors, please, report to [issue tracker](https://github.com/d2r2/jsonc-bash/issues).

Credits
-------

This library is inspired by minimalistic JSON parser written by Serge Zaitsev: https://github.com/zserge/jsmn.

Links
-----

* Test suite used which cover a lot of parsers, but only one BASH parser found there. Keeps big collection of JSON files to check parser compliance with the standard: https://github.com/nst/JSONTestSuite

License
-------

This software is distributed under MIT license.
