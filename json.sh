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

# Success
JSON_EXIT_OK=0
# Invalid character inside JSON string
JSON_EXIT_ERROR_INVAL=1
# The string is not a full JSON packet, more bytes expected
JSON_EXIT_ERROR_PART=2
	
# Point to the line in case of parse error result
JSON_LINE_ERROR=0

# Tokens info which keep all information about parsed JSON structure.
# These variables are used to traverse and search keys,
# enumerate arrays and so on.
jt_type=()      # type (object, array, string, primitive)
jt_content=()   # content for strings and primitives
jt_parent=()    # reference to parent token
jt_size=()      # number of children tokens

# Get character from ASCII code
# Taken from here:
# 	https://unix.stackexchange.com/questions/92447/bash-script-to-get-ascii-values-for-alphabet
chr() {
  [ "$1" -lt 256 ] || return 1
  printf "\\$(printf '%03o' "$1")"
} # chr

# Get ASCII code from character
# Taken from here:
# 	https://unix.stackexchange.com/questions/92447/bash-script-to-get-ascii-values-for-alphabet
ord() {
  LC_CTYPE=C printf '%d' "'$1"
} # ord


# Read content of JSON string.
# Do not use subshell to return result
# to improve performance, but use
# read_string_res variable instead.
read_string()
{
	local str
	local ch
	while read -r -n1 ch; do
		#local ch="${json[$pos]}"

		# Backslash: extra symbol expected
		if [[ "$ch" == "\\" ]]; then
			str="${str}${ch}"
			if ! read -r -n1 ch; then
				return $JSON_EXIT_ERROR_PART
			fi
			# Allowed escaped symbols
			if [[ "$ch" =~ [\"/\\bfrnt] ]]; then
				str="${str}${ch}"
			# Allows escaped symbol \uXXXX
			elif [[ "$ch" == "u" ]]; then
				str="${str}${ch}"
				local unicode
				# Read next 4 characters as Unicode hex code
				if ! read -r -n4 unicode; then
					return $JSON_EXIT_ERROR_PART
				fi
				for ch in $(echo $unicode | grep -o .); do
					# If it isn't a hex character we have error
					if [[ $(ord "$ch") -ge 48 && $(ord "$ch") -le 57 || \
						$(ord "$ch") -ge 65 && $(ord "$ch") -le 70 || \
						$(ord "$ch") -ge 97 && $(ord "$ch") -le 102 ]]; then
						:
					else
						return $JSON_EXIT_ERROR_INVAL
					fi
				done
				str="${str}${unicode}"
			else
				return $JSON_EXIT_ERROR_INVAL
			fi
		# Quote: end of string
		elif [[ "$ch" == "\"" ]]; then
			read_string_res=$str
			return $JSON_EXIT_OK
		elif [[ "$ch" == "" ]]; then
			str="${str} "
		else
			str="${str}${ch}"
		fi
	done

	return $JSON_EXIT_ERROR_PART
} # read_string

# Parse JSON file from pipe to tokens.
# There are 4 token types only for JSON: object, array, string and primitive.
# Tokens are stored in one dimention array, but jt_parent and jt_size arrays
# help travers JSON structure in binary tree data structure manner.
parse_json_from_pipe()
{
	# Current line index
	local line_ind=1
	# Comment mode flag: 0 - no comment mode, 1 - single line comment, 2 - multiline comment
	local skip_comments="0"
	# Next token index
	local tok_pos=0
	# Super token
	local tok_sup=-1
	# Clear global arrays
	jt_type=()      # type (object, array, string, primitive)
	jt_content=()   # content for strings and primitives
	jt_parent=()    # reference to parent token
	jt_size=()      # number of children tokens
	# Makes sure that all opening brackets ({[) have matching closing brackets (}])
	local t_closed=()

	# Read line by line from pipe
	local line; while IFS= read -r line || [ -n "$line" ]; do

		#echo "$line"

		if [[ "$skip_comments" == "2" ]]; then
			if [[ $(echo "$line" | sed -E -n "s/^.*(\*\/)/\1/p") != "" ]]; then
				line=$(echo "$line" | sed -E -n "s/^.*\*\/(.*)/\1/p")
				#echo "comments removed: $line"
			else
				line_ind=$(( $line_ind + 1 ))
				continue
			fi
		fi
		skip_comments="0"

		# Read char by char from nested pipe
		local buf_ch; while read -r -n1 buf_ch; do
	
			local read_char=1
			local ch=$buf_ch

			while [[ $read_char -eq 1 ]]; do
			
				read_char=0
				#echo "$ch" 1>&2

				# Start of object/array block
				if [[ "$ch" == "{" || "$ch" == "[" ]]; then
					#echo "$tok_pos object/array start" 1>&2
			
					local type; [[ "$ch" == "{" ]] && type="o" || type="a" # token object/array
			
					# Create object or array token
					jt_type+=($type)
					jt_content+=("")
					jt_size+=(0)
					jt_parent+=(-1)
			
					if [[ $tok_sup -ne -1 ]]; then
						# An object can't become a key
						if [[ ${jt_type[$tok_sup]} == "o" ]]; then
							JSON_LINE_ERROR=$line_ind
							return $JSON_EXIT_ERROR_INVAL
						fi
						jt_size[$tok_sup]=$(( jt_size[$tok_sup] + 1 ))
						jt_parent[$tok_pos]=$tok_sup
					fi
			
					t_closed+=(0)
					tok_sup=$tok_pos

					tok_pos=$(( $tok_pos + 1 ))
		
				# End of object/array block
				elif [[ "$ch" == "}" || "$ch" == "]" ]]; then
					#echo "object/array end" 1>&2
			
					local type; [[ "$ch" == "}" ]] && type="o" || type="a" # token object/array

					if [[ $tok_pos -eq 0 ]]; then
						#echo "ERROR }1"
						JSON_LINE_ERROR=$line_ind
						return $JSON_EXIT_ERROR_INVAL
					fi

					local tok_pos2=$(( $tok_pos - 1 ))
					while [[ $tok_pos2 -ge 0 ]]; do
						if [[ ${t_closed[$tok_pos2]} -eq 0 ]]; then
							if [[ ${jt_type[$tok_pos2]} != $type ]]; then
								#echo "ERROR }2"
								JSON_LINE_ERROR=$line_ind
								return $JSON_EXIT_ERROR_INVAL
							fi

							t_closed[$tok_pos2]=1
							tok_sup=${jt_parent[$tok_pos2]}
							break
						fi

						if [[ ${jt_parent[$tok_pos2]} -eq -1 ]]; then
							if [[ ${jt_type[$tok_pos2]} != $type || $tok_sup -eq -1 ]]; then
								#echo "ERROR }3"
								JSON_LINE_ERROR=$line_ind
								return $JSON_EXIT_ERROR_INVAL
							fi
							break
						fi
						tok_pos2=${jt_parent[$tok_pos2]}
					done

				# Skip space characters
				elif [[ "$ch" =~ [[[:space:]]] || "$ch" == "" || "$ch" == "\r" || "$ch" == "\n" || "$ch" == "\t" ]]; then
					#echo "space" 1>&2
					:

				# Start of comment block
				elif [[ "$ch" == "/" ]]; then
					if ! read -r -n1 ch; then
						JSON_LINE_ERROR=$line_ind
						return $JSON_EXIT_ERROR_INVAL
					fi

					# Single line comment block detected
					if [[ "$ch" == "/" ]]; then
						skip_comments="1"
						break
					# Multiline comment block detected
					elif [[ "$ch" == "*" ]]; then
						skip_comments="2"
						break
					else
						# Unexpected char
						JSON_LINE_ERROR=$line_ind
						return $JSON_EXIT_ERROR_INVAL
					fi
				# Quote: start of string
				elif [[ "$ch" == "\"" ]]; then
					#echo "string" 1>&2

					# Skip opening quote
					read_string "$pos"; local retval=$?; local val="$read_string_res"
					if [[ $retval -ne $JSON_EXIT_OK ]]; then
						JSON_LINE_ERROR=$line_ind
						return $retval
					fi
					#echo "string=$val" 1>&2

					# Create string token
					jt_type+=("s")
					jt_content+=("$val")
					jt_size+=(0)
					t_closed+=(1)
					jt_parent+=($tok_sup)
			
					[[ $tok_sup -ne -1 ]] && jt_size[$tok_sup]=$(( jt_size[$tok_sup] + 1 ))
			
					tok_pos=$(( $tok_pos + 1 ))
				elif [[ "$ch" == ":" ]]; then
					#echo "divider" 1>&2
					tok_sup=$(( $tok_pos - 1 ))
				elif [[ "$ch" == "," ]]; then
					#echo "comma" 1>&2
					[[ $tok_sup -ne -1 ]] && [[ ${jt_type[$tok_sup]} != "o" && ${jt_type[$tok_sup]} != "a" ]] && \
						tok_sup=${jt_parent[$tok_sup]}
				# Starting char of primitive token, like (-)number, null, false, true and other
				elif [[ "$ch" =~ [\-0-9tfn] ]]; then
					#echo "primitive" 1>&2
					if [[ $tok_sup -ne -1 ]]; then
						if [[ ${jt_type[$tok_sup]} == "o" || \
							${jt_type[$tok_sup]} == "s" && ${jt_size[$tok_sup]} -ne 0 ]]; then
							JSON_LINE_ERROR=$line_ind
							return $JSON_EXIT_ERROR_INVAL
						fi
					fi
					# Save first char of primitive
					local prim=$ch
					# Read rest part of primitive
					while read -r -n1 ch; do
						if [[ "$ch" =~ [[[:space:]]] || "$ch" == ":" || "$ch" == "," || "$ch" == "" || \
							"$ch" == "]" || "$ch" == "}" || "$ch" == "\t" || "$ch" == "\r" || "$ch" == "\n" ]]; then
							break
						else
							prim=$prim$ch
						fi
					done
					read_char=1
					#echo "primitive=$prim" 1>&2

					# Create primitive token
					jt_type+=("p")
					jt_content+=("$prim")
					jt_size+=(0)
					t_closed+=(1)
					jt_parent+=($tok_sup)
			
					[[ $tok_sup -ne -1 ]] && jt_size[$tok_sup]=$(( ${jt_size[$tok_sup]} + 1 ))

					tok_pos=$(( $tok_pos + 1 ))
				else
					# Unexpected char
					JSON_LINE_ERROR=$line_ind
					return $JSON_EXIT_ERROR_INVAL
				fi
			done

			if [[ "$skip_comments" != "0" ]]; then
				break
			fi

		done < <(echo "$line")
		
		if [[ "$skip_comments" == "1" ]]; then
			skip_comments="0"
		fi

		line_ind=$(( $line_ind + 1 ))
	done
	
	# Error if comments block is not closed
	if [[ "$skip_comments" != "0" ]]; then
		JSON_LINE_ERROR=$line_ind
		return $JSON_EXIT_ERROR_PART
	fi

	# Verify that all opening brackets {[
	# have corresponding closing brackets }].
	local i=${#jt_type[@]}
	i=$(( $i - 1 ))
	while [[ $i -ge 0 ]]; do
		if [[ ${t_closed[$i]} -eq 0 ]]; then
			JSON_LINE_ERROR=$line_ind
			return $JSON_EXIT_ERROR_PART
		fi
		i=$(( $i - 1 ))
	done

	return $JSON_EXIT_OK
} # parse_json_from_pipe


# Print parsed JSON tokens for debug purpose.
# Output arrays jt_type, jt_content, jt_parent, jt_size
# which allow to travers results in a binary tree manner.
print_json_tokens()
{
	echo "JSON token count = ${#jt_type[@]}"
	local i; for i in "${!jt_type[@]}"; do
		#echo "index $i, type ${jt_type[$i]}"
		if [[ "${jt_type[$i]}" == "o" ]]; then
			echo "$i object parent ${jt_parent[$i]} size ${jt_size[$i]}"
		elif [[ "${jt_type[$i]}" == "a" ]]; then
			echo "$i array parent ${jt_parent[$i]} size ${jt_size[$i]}"
		elif [[ "${jt_type[$i]}" == "s" ]]; then
			local str="${jt_content[$i]}"
			echo "$i \"${str}\" parent ${jt_parent[$i]} size ${jt_size[$i]}"
		elif [[ "${jt_type[$i]}" == "p" ]]; then
			local str="${jt_content[$i]}"
			echo "$i |${str}| parent ${jt_parent[$i]} size ${jt_size[$i]}"
		fi
	done
} # print_json_tokens


# Jump to next parsed token item.
# Do not use subshell to return result
# to improve performance, but use
# next_item_res variable instead.
next_item()
{
	local i=$1
	local size=${jt_size[$i]}
	#echo "item $i size $size" 1>&2

	local k=$(( $i + 1 ))
	if [[ $size -gt 0 ]]; then
		local j=0
		while [[ $j -lt $size ]]; do
			next_item $k; k=$next_item_res
			j=$(( $j + 1 ))
		done
	fi
	#echo "Found next_item: $k" 1>&2
	next_item_res=$k
} # next_item


# Get token index with XML XPath style, where we have
# array of entries [key1, key2 ... keyN] to search for JSON keys.
get_json_path_index()
{
	local j=1
	#echo "First ${!j}" 1>&2
	local i=1
	while [[ $i -lt ${#jt_type[@]} ]]; do
		if [[ "${jt_type[$i]}" != "s" && "${jt_type[$i]}" != "a" ]]; then
			echo "-1"
			return
		# Employ case insensitive compare with ^^
		elif [[ "${jt_type[$i]}" == "s" && "${jt_content[$i]^^}" == "${!j^^}" ]]; then
			#echo "Found ${!j}" 1>&2
			j=$(( $j + 1 ))
			if [[ $j -gt $# ]]; then
				#echo "Stop on $i" 1>&2
				echo $i
				return
			else
				i=$(( $i + 1 ))
				while [[ "${jt_type[$i]}" != "s" && "${jt_type[$i]}" != "a" ]]; do
					i=$(( $i + 1 ))
				done
			fi
		# If token is an array and search patern is an integer
		elif [[ "${jt_type[$i]}" == "a" && "${!j}" =~ ^[0-9]+$ ]]; then
			# If search index exceed array size, return error
			if [[ ${!j} -ge ${jt_size[$i]} ]]; then
				echo -1
				return
			fi
			#echo "Search index array ${!j}" 1>&2
			i=$(( $i + 1 ))
			local k=0
			while [[ $k -lt ${!j} ]]; do
				#i=$(next_item $i)
				next_item $i; i=$next_item_res
				k=$(( $k + 1 ))
			done
			j=$(( $j + 1 ))
			if [[ $j -gt $# ]]; then
				#echo "Stop on $i" 1>&2
				echo $i
				return
			else
				while [[ "${jt_type[$i]}" != "s" && "${jt_type[$i]}" != "a" ]]; do
					i=$(( $i + 1 ))
				done
				#echo "Found index $k on $i" 1>&2
			fi
		else
			next_item $i; i=$next_item_res
		fi
	done
	echo "-1"
} # get_json_path_index


# Select value with XML XPath style, where we have
# array of entries [key1, key2 ... keyN] to search for JSON keys.
# Return corresponding key value, either array size for specific key.
get_json_path_value()
{
	local i=$(get_json_path_index $@)
	if [[ $i -ne -1 ]]; then
		# In case of key token prolong to next token
		# (key token always has size > 0)
		if [[ "${jt_type[$i]}" == "s" && "${jt_size[$i]}" -ne 0 ]]; then
			i=$(( $i + 1 ))
		fi
		if [[ "${jt_type[$i]}" == "s" || "${jt_type[$i]}" == "p" ]]; then
			echo -e "${jt_content[$i]}"
			return 0
		elif [[ "${jt_type[$i]}" == "a" ]]; then
			echo "${jt_size[$i]}"
			return 0
		fi
	fi
	# Report that value doesn't found
	return 1
} # get_json_path_value


# Take JSON from file and send it to STDIN to parse with call to parse_json_from_pipe
parse_json()
{
	local f=$1
	parse_json_from_pipe < "$f"; local retval=$?
	if [[ $retval -ne $JSON_EXIT_OK ]]; then
		local ret_desc; [[ $retval -eq $JSON_EXIT_ERROR_INVAL ]] && ret_desc="invalid character" || \
			[[ $retval -eq $JSON_EXIT_ERROR_PART ]] && ret_desc="unexpected end" 
		echo "Error $ret_desc at line $JSON_LINE_ERROR"
		return 1
	fi
} # parse_json

