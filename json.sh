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

# Success
JSON_EXIT_OK=0
# Invalid character inside JSON string
JSON_EXIT_ERROR_INVAL=1
# The string is not a full JSON packet, more bytes expected
JSON_EXIT_ERROR_PART=2
# Source file never parsed error
JSON_EXIT_NEVER_PARSED=10
	
# Flag to identify that source file parsed
JSON_EVER_PARSED=0
# Point to the line in case of parse error result
JSON_LINE_ERROR=0

# Flag to print warning if XPath search contains invalid array index
JSON_WARN_INVALID_PATH_INDEX=1

# Tokens info which keep all information about parsed JSON structure.
# These variables are used to traverse and search keys,
# enumerate arrays and so on.
jt_type=()      # type (object, array, string, primitive)
jt_content=()   # content for strings and primitives
jt_parent=()    # reference to parent token
jt_size=()      # count of direct children subtrees in json structure
jt_size_tok=()	# total number of all child tokens

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

# Parse JSON/JSONC file data from pipe to tokens.
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
	# Position of parent token, which own current token
	local parent_pos=-1
	# Clear global arrays
	jt_type=()      # type (object, array, string, primitive)
	jt_content=()   # content for strings and primitives
	jt_parent=()    # reference to parent token
	jt_size=()      # count of direct children subtrees in json structure
	jt_size_tok=()	# total number of all child tokens
	
	local t_stack=() # Save start token position for nested objects
	
	#local debug=true

	# Set parse attempt was implemented
	JSON_EVER_PARSED=1

	# Start read LINE loop from input pipe.
	# Read line by line from pipe.
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

		# Start read CHAR loop from input LINE.
		# Read char by char from nested pipe, which is line.
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
					jt_size_tok+=(-1)
					jt_parent+=(-1)

					t_stack+=($tok_pos)
			
					if [[ $parent_pos -ne -1 ]]; then
						# Parent token can't be an object
						if [[ ${jt_type[$parent_pos]} == "o" ]]; then
							[[ $debug == true ]] && echo "DEBUG: PJFP: error in line $line_ind: an object can't become a key" 1>&2
							JSON_LINE_ERROR=$line_ind
							return $JSON_EXIT_ERROR_INVAL
						# If parent element is a string, than it size must be no more than 1,
						# otherwise it means, that probably comma is missing
						elif [[ ${jt_type[$parent_pos]} == "s" && ${jt_size[$parent_pos]} -gt 0 ]]; then
							[[ $debug == true ]] && echo "DEBUG: PJFP: error in line $line_ind: probably comma is missing" 1>&2
							JSON_LINE_ERROR=$line_ind
							return $JSON_EXIT_ERROR_INVAL
						fi
						jt_size[$parent_pos]=$(( ${jt_size[$parent_pos]} + 1 ))
						jt_parent[$tok_pos]=$parent_pos
					fi

					parent_pos=$tok_pos

					tok_pos=$(( $tok_pos + 1 ))
		
				# End of object/array block
				elif [[ "$ch" == "}" || "$ch" == "]" ]]; then
					#echo "object/array end" 1>&2
			
					local type; [[ "$ch" == "}" ]] && type="o" || type="a" # token object/array

					local stack_depth=${#t_stack[@]}

					if [[ $stack_depth -eq 0 ]]; then
						#echo "ERROR }1"
						[[ $debug == true ]] && echo "DEBUG: PJFP: error in line $line_ind: [{ more than }]" 1>&2
						JSON_LINE_ERROR=$line_ind
						return $JSON_EXIT_ERROR_PART
					fi

					local sup_start=${t_stack[$(( $stack_depth - 1 ))]}
					parent_pos=${jt_parent[$sup_start]}

					if [[ "${jt_type[$sup_start]}" != "$type" ]]; then
						[[ $debug == true ]] && echo "DEBUG: PJFP: error in line $line_ind: open ${jt_type[$sup_start]} do not match close $type" 1>&2
						JSON_LINE_ERROR=$line_ind
						return $JSON_EXIT_ERROR_PART
					fi

					#echo "sup_start=$sup_start; sup_end=$tok_pos; parent_pos=$parent_pos; stack=${t_stack[@]}" 1>&2
					local tok_size=$(( $tok_pos - $sup_start ))
					jt_size_tok[$sup_start]=$tok_size

					# remove last element of array
					unset 't_stack[${#t_stack[@]}-1]'

					if [[ $parent_pos -ne -1 && ${jt_type[$parent_pos]} != "o" && ${jt_type[$parent_pos]} != "a" ]]; then
						jt_size_tok[$parent_pos]=$(( ${jt_size_tok[$parent_pos]} + $tok_size ))					
					fi					
		
				# Skip space characters
				elif [[ "$ch" =~ [[[:space:]]] || "$ch" == "" || "$ch" == "\r" || "$ch" == "\n" || "$ch" == "\t" ]]; then
					#echo "space" 1>&2
					:

				# Start of multiline comment block
				elif [[ "$ch" == "/" ]]; then
					if ! read -r -n1 ch; then
						[[ $debug == true ]] && echo "DEBUG: PJFP: error in line $line_ind: unexpected comment / end" 1>&2
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
						[[ $debug == true ]] && echo "DEBUG: PJFP: error in line $line_ind: unexpected char for comment /" 1>&2
						JSON_LINE_ERROR=$line_ind
						return $JSON_EXIT_ERROR_INVAL
					fi
				# Quote: start of string
				elif [[ "$ch" == "\"" ]]; then
					#echo "string" 1>&2

					# If parent element is a string, than it size must be no more than 1,
					# otherwise it means, that probably comma is missing
					if [[ $parent_pos -ne -1 && ${jt_type[$parent_pos]} == "s" && ${jt_size[$parent_pos]} -gt 0 ]]; then
						JSON_LINE_ERROR=$line_ind
						return $JSON_EXIT_ERROR_PART
					fi

					# Skip opening quote
					read_string "$pos"; local retval=$?; local val="$read_string_res"
					if [[ $retval -ne $JSON_EXIT_OK ]]; then
						[[ $debug == true ]] && echo "DEBUG: PJFP: error in line $line_ind: problem with reading string" 1>&2
						JSON_LINE_ERROR=$line_ind
						return $retval
					fi
					#echo "string=$val" 1>&2

					# Create string token
					jt_type+=("s")
					jt_content+=("$val")
					jt_size+=(0)
					jt_size_tok+=(1)
					jt_parent+=($parent_pos)
			
					if [[ $parent_pos -ne -1 ]]; then
						jt_size[$parent_pos]=$(( ${jt_size[$parent_pos]} + 1 ))
						local tok_size=$(( $tok_pos - $parent_pos ))
						jt_size_tok[$parent_pos]=$(( ${jt_size_tok[$parent_pos]} + $tok_size ))
					fi
			
					tok_pos=$(( $tok_pos + 1 ))

				elif [[ "$ch" == ":" ]]; then
					#echo "divider" 1>&2
					parent_pos=$(( $tok_pos - 1 ))

				elif [[ "$ch" == "," ]]; then
					#echo "comma" 1>&2
					if [[ $parent_pos -ne -1 && ${jt_type[$parent_pos]} != "o" && ${jt_type[$parent_pos]} != "a" ]]; then
						parent_pos=${jt_parent[$parent_pos]}
					fi

				# Starting char of primitive token, like (-)number, null, false, true and other
				elif [[ "$ch" =~ [\-0-9tfn] ]]; then
					#echo "primitive" 1>&2
					if [[ $parent_pos -ne -1 ]]; then
						if [[ ${jt_type[$parent_pos]} == "o" || \
							${jt_type[$parent_pos]} == "s" && ${jt_size[$parent_pos]} -ne 0 ]]; then
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
					jt_size_tok+=(1)
					jt_parent+=($parent_pos)
			
					if [[ $parent_pos -ne -1 ]]; then
						jt_size[$parent_pos]=$(( ${jt_size[$parent_pos]} + 1 ))
						jt_size_tok[$parent_pos]=$(( ${jt_size_tok[$parent_pos]} + 1 ))
					fi

					tok_pos=$(( $tok_pos + 1 ))

				else
					# Unexpected char
					[[ $debug == true ]] && echo "DEBUG: PJFP: error in line $line_ind: unexpected char" 1>&2
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
		[[ $debug == true ]] && echo "DEBUG: PJFP: error in line $line_ind: comments block is not closed" 1>&2
		JSON_LINE_ERROR=$line_ind
		return $JSON_EXIT_ERROR_PART
	fi

	# Verify that all opening brackets {[
	# have corresponding closing brackets }].
	if [[ ${#t_stack[@]} -gt 0 ]]; then
		[[ $debug == true ]] && echo "DEBUG: PJFP: error in line $line_ind: [{ blocks does not closed" 1>&2
		JSON_LINE_ERROR=$line_ind
		return $JSON_EXIT_ERROR_PART
	fi


	return $JSON_EXIT_OK
} # parse_json_from_pipe


# Print parsed JSON tokens for debug purpose.
# Output arrays jt_type, jt_content, jt_parent, jt_size and jt_size_tok
# which allow to travers results in a binary tree manner.
print_json_tokens()
{
	echo "JSON token count = ${#jt_type[@]}"
	local i; for i in "${!jt_type[@]}"; do
		str="$i $(print_json_token $i)"
		echo "$str"
	done
} # print_json_tokens

# Print JSON token by index specified in $1 for debug purpose.
# Arguments:
#	- JSON token index to get data from jt_type, jt_content, jt_parent, jt_size and jt_size_tok arrays
print_json_token()
{
	local index="$1"

	if [[ $index -gt -1 ]]; then
		if [[ "${jt_type[$index]}" == "o" ]]; then
			echo -n "object parent ${jt_parent[$index]} size ${jt_size[$index]} size_ind ${jt_size_tok[$index]}"
		elif [[ "${jt_type[$index]}" == "a" ]]; then
			echo -n "array parent ${jt_parent[$index]} size ${jt_size[$index]} size_ind ${jt_size_tok[$index]}"
		elif [[ "${jt_type[$index]}" == "s" ]]; then
			local str="${jt_content[$index]}"
			echo -n "\"${str}\" parent ${jt_parent[$index]} size ${jt_size[$index]} size_ind ${jt_size_tok[$index]}"
		elif [[ "${jt_type[$index]}" == "p" ]]; then
			local str="${jt_content[$index]}"
			echo -n "|${str}| parent ${jt_parent[$index]} size ${jt_size[$index]} size_ind ${jt_size_tok[$index]}"
		fi
	else
		echo -n "EOF"
	fi
} # print_json_token


# Recursive function.
# Searching for next token at same level as start index.
# At the same time method fill array jt_size_tok for better indexing in next search requests.
# Arguments:
# 	- variable name to return found index of next token located at same level
# 	- index position to start search
# 	- debug switch on/off
next_item()
{
	declare -n output="$1"		# -n	make NAME a reference to the variable named by its value
	local index=$2
	local debug=$3
	[[ $debug == true ]] && echo "DEBUG: NI: move to next from item $index $(print_json_token $index)" 1>&2

	local sz_ind=${jt_size_tok[$index]}
	if [[ $sz_ind -gt 0 ]]; then
		index=$(( $index + $sz_ind ))
	fi

	if [[ $index -gt ${#jt_size[@]} ]]; then
		output=-1
		#return 1
	else
		output=$index
		#return 0
	fi
	[[ $debug == true ]] && echo "DEBUG: NI: output=\"$output\"" 1>&2
	[[ $debug == true ]] && echo "DEBUG: NI: found next_item $index $(print_json_token $index)" 1>&2
} # next_item


# Get token index with XML XPath style, where we have
# array of entries [key1, key2 ... keyN] to search for JSON keys.
# Arguments:
# 	- variable name to return function result
#	- XPath defined by all the following parameters to search
# Return index of JSON element if XPath found, either -1 if no XPath found.
get_json_path_index()
{
	declare -n output="$1"		# -n	make NAME a reference to the variable named by its value
	local argss=("$@")
	local search_keys=("${argss[@]:1}")
	local start_index=0
	get_json_path_index_internal "gjpii_res" ${start_index} ${search_keys[@]}
	output=$gjpii_res
	unset gjpii_res
} # get_json_path_index

# Recursive function.
# Get token index with XML XPath style, where we have
# array of entries [key1, key2 ... keyN] to search for JSON keys.
# Arguments:
# 	- variable name to return function result
#	- index position to start search
#	- XPath defined by all the following parameters to search
# Return value contains index of found XPath, either -1 if no path found.
get_json_path_index_internal()
{
	declare -n output="$1"		# -n	make NAME a reference to the variable named by its value
	local argss=("$@")
	local index=${argss[1]}
	local search_keys=("${argss[@]:2}")
	local search_val="${search_keys[0]}"
	#local debug=true
	#local debug_ni=true

	if [[ "${jt_type[$index]}" == "o" ]]; then
		local subtree_count=${jt_size[$index]}

		index=$(( $index + 1 ))

		local k=0
		while [[ $k -lt $subtree_count ]]; do
			if [[ "${jt_type[$index]}" == "s" && "${jt_content[$index]^^}" == "${search_val^^}" ]]; then
				[[ $debug == true ]] && echo "DEBUG: GJPI: found ${search_val} at item ${index} $(print_json_token $index)" 1>&2

				local search_keys2=("${search_keys[@]:1}")

				if [[ ${#search_keys2[@]} -gt 0 ]]; then
					# move to next level
					local index2=$(( $index + 1 ))
					get_json_path_index_internal "gjpii_res" $index2 ${search_keys2[@]}
					index2=$gjpii_res
					unset gjpii_res

					if [[ $index2 -ne -1 ]]; then
						output=$index2
						return
					fi
				else
					[[ $debug == true ]] && echo "DEBUG: GJPI: success!!!" 1>&2
					output=$index
					return
				fi
			fi
		
			#local output2	
			next_item "gjpii_ni_res" $index $debug_ni
			index=$gjpii_ni_res
			unset gjpii_ni_res
		
			k=$(( $k + 1 ))
		done
		[[ $debug == true ]] && echo "DEBUG: GJPI: ${search_val} not found" 1>&2
	elif [[ "${jt_type[$index]}" == "a" ]]; then
		local subtree_count=${jt_size[$index]}
		
		if [[ ! "$search_val" =~ ^[0-9]+$ ]]; then
			echo "ERROR: GJPI: key $search_val must be an integer value to index array at ${index}" 1>&2
			output=-1
			return
		fi

		if [[ $search_val -ge $subtree_count ]]; then
			[[ $JSON_WARN_INVALID_PATH_INDEX == 1 ]] && echo "WARNING: GJPI: key $search_val exceed array at ${index} of size $subtree_count" 1>&2
			output=-1
			return
		fi

		local index2=$(( $index + 1 ))
		local k=0
		while [[ $k -lt ${search_val} ]]; do
			#local output2
			next_item "gjpii_ni_res" $index2 $debug_ni
			index2=$gjpii_ni_res
			unset gjpii_ni_res

			k=$(( $k + 1 ))
		done
		
		[[ $debug == true ]] && echo "DEBUG: GJPI: found ${search_val} at item ${index2} $(print_json_token $index2)" 1>&2

		local search_keys2=("${search_keys[@]:1}")

		if [[ ${#search_keys2[@]} -gt 0 ]]; then
			# move to next level
			get_json_path_index_internal "gjpii_res" $index2 ${search_keys2[@]}
			index2=$gjpii_res
			output=$index2
			return
		else
			[[ $debug == true ]] && echo "DEBUG: GJPI: success!!!" 1>&2
			output=$index2
			return
		fi
	else
		echo "ERROR: GJPI: search must start from object or array token position, but found $(print_json_token $index)" 1>&2
		output=-1
		return
	fi

	output=-1
} # get_json_path_index_internal



# Select value with XML XPath style, where we have
# array of entries [key1, key2 ... keyN] to search for JSON keys.
# Return corresponding key value, either array size for specific key.
# Arguments:
# 	- variable name to return function result
#	- XPath defined by all the following parameters to search
# Return JSON value if XPath found, either <empty> value if no XPath found.
get_json_path_value()
{
	declare -n output="$1"		# -n	make NAME a reference to the variable named by its value
	local argss=("$@")
	local search_keys=("${argss[@]:1}")

	get_json_path_index "gjpi_res" ${search_keys[@]}
	local i=$gjpi_res
	unset gjpi_res

	#echo "DEBUG: GSPV: found index $i" 1>&2
	if [[ $i -gt -1 ]]; then
		# In case of key token prolong to next token
		# (key token always has size > 0)
		if [[ "${jt_type[$i]}" == "s" && "${jt_size[$i]}" -ne 0 ]]; then
			i=$(( $i + 1 ))
		fi
		if [[ "${jt_type[$i]}" == "s" || "${jt_type[$i]}" == "p" ]]; then
			# set result to content value 
			output=$(printf %b "${jt_content[$i]}")

			#echo -e "${jt_content[$i]}"
			return 0
		elif [[ "${jt_type[$i]}" == "a" ]]; then
			# set result to array length
			output=${jt_size[$i]}

			#echo "${jt_size[$i]}"
			return 0
		fi
	else
		# set result to empty string, once no path found
		output=""

		if [[ $JSON_EVER_PARSED -eq 0 ]]; then
			echo "ERROR: JSON source file must be processed first. Run parse_json or parse_json_from_pipe in advance" 1>&2
		fi
	fi
	# Report that value doesn't found
	return 1
} # get_json_path_value


# Take JSON/JSONC from file and send it to STDIN to parse with call to parse_json_from_pipe
# Arguments:
# 	- path to file with JSON/JSONC to parse
parse_json()
{
	local f=$1
	parse_json_from_pipe < "$f"; local retval=$?
	if [[ $retval -ne $JSON_EXIT_OK ]]; then
		local ret_desc; [[ $retval -eq $JSON_EXIT_ERROR_INVAL ]] && ret_desc="invalid character" || \
			[[ $retval -eq $JSON_EXIT_ERROR_PART ]] && ret_desc="unexpected end" 
		echo "ERROR $ret_desc at line $JSON_LINE_ERROR" 1>&2
		return 1
	fi
} # parse_json

