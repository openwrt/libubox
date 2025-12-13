#!/bin/bash

JSON_SCRIPT=tests.json
JSON_SCRIPT_BIN=${TEST_JSON_SCRIPT=:-./json_script-example}
FILE_STDOUT=tests.stdout
FILE_STDERR=tests.stderr
FILE_EXPECTED=tests.expected

call_json_script() {
	#export LD_PRELOAD=../libjson_script.so
	$JSON_SCRIPT_BIN "$@" "$JSON_SCRIPT" >"$FILE_STDOUT" 2>"$FILE_STDERR"
}

assertStdioEquals() {
	local expected="$1"
	local file_stdio="$2"

	echo "$expected" >"$FILE_EXPECTED"
	if [ -z "$expected" ]; then
		# we are expecting empty output, but we deliberately added a newline
		# with echo above, so adding another echo to compensate for that
		echo >>"$file_stdio"
	fi
	diff -up "$FILE_EXPECTED" "$file_stdio" >/dev/null 2>&1 || {
		cat >&2 <<EOF
|--- expecting
$expected<
|--- actual
$(cat $file_stdio)<
|--- END
EOF
		exit 1
	}
}

assertStdoutEquals() {
	assertStdioEquals "$1" "$FILE_STDOUT"
}

assertStderrEquals() {
	assertStdioEquals "$1" "$FILE_STDERR"
}

test_bad_json() {
	cat >"$JSON_SCRIPT" <<-EOF
	[
		[ ]
		[ ]
	]
	EOF
	call_json_script
	assertStderrEquals "load JSON data from $JSON_SCRIPT failed."
}

test_expr_eq() {
	cat >"$JSON_SCRIPT" <<-EOF
	[
		[ "if",
			[ "eq", "VAR", "foo" ],
			[ "echo", "bar" ],
			[ "echo", "baz" ]
		]
	]
	EOF
	call_json_script "VAR=foo"
	assertStdoutEquals "echo bar"
	call_json_script "VAR=xxx"
	assertStdoutEquals "echo baz"
}

test_expr_has() {
	cat >"$JSON_SCRIPT" <<-EOF
	[
		[ "if",
			[ "has", "VAR" ],
			[ "echo", "bar" ],
			[ "echo", "baz" ]
		]
	]
	EOF
	call_json_script "VAR=foo"
	assertStdoutEquals "echo bar"
	call_json_script
	assertStdoutEquals "echo baz"
}

test_expr_regex_single() {
	cat >"$JSON_SCRIPT" <<-EOF
	[
		[ "if",
			[ "regex", "VAR", ".ell." ],
			[ "echo", "bar" ],
			[ "echo", "baz" ]
		]
	]
	EOF
	call_json_script "VAR=hello"
	assertStdoutEquals "echo bar"
	call_json_script "VAR=.ell."
	assertStdoutEquals "echo bar"
	call_json_script
	assertStdoutEquals "echo baz"
	call_json_script "VAR="
	assertStdoutEquals "echo baz"
	call_json_script "VAR=hell"
	assertStdoutEquals "echo baz"
}

test_expr_regex_multi() {
	cat >"$JSON_SCRIPT" <<-EOF
	[
		[ "if",
			[ "regex", "VAR", [ ".ell.", "w.rld" ] ],
			[ "echo", "bar" ],
			[ "echo", "baz" ]
		]
	]
	EOF
	call_json_script "VAR=hello"
	assertStdoutEquals "echo bar"
	call_json_script "VAR=world"
	assertStdoutEquals "echo bar"
	call_json_script "VAR=.ell."
	assertStdoutEquals "echo bar"
	call_json_script "VAR=w.rld"
	assertStdoutEquals "echo bar"
	call_json_script
	assertStdoutEquals "echo baz"
	call_json_script "VAR="
	assertStdoutEquals "echo baz"
	call_json_script "VAR=hell"
	assertStdoutEquals "echo baz"
}

test_expr_not() {
	cat >"$JSON_SCRIPT" <<-EOF
	[
		[ "if",
			[ "not", [ "has", "VAR" ] ],
			[ "echo", "bar" ],
			[ "echo", "baz" ]
		]
	]
	EOF
	call_json_script "VAR=foo"
	assertStdoutEquals "echo baz"
	call_json_script
	assertStdoutEquals "echo bar"
}

test_expr_and() {
	cat >"$JSON_SCRIPT" <<-EOF
	[
		[ "if",
			[ "and", [ "eq", "EQVAR", "eqval" ],
					 [ "regex", "REGEXVAR", "regex..." ]
			],
			[ "echo", "bar" ],
			[ "echo", "baz" ]
		]
	]
	EOF
	call_json_script "EQVAR=eqval" "REGEXVAR=regexval"
	assertStdoutEquals "echo bar"
	call_json_script "EQVAR=foo"
	assertStdoutEquals "echo baz"
	call_json_script "REGEXVAR=regex***"
	assertStdoutEquals "echo baz"
	call_json_script
	assertStdoutEquals "echo baz"
}

test_expr_or() {
	cat >"$JSON_SCRIPT" <<-EOF
	[
		[ "if",
			[ "or", [ "not", [ "eq", "EQVAR", "eqval" ] ],
					[ "regex", "REGEXVAR", [ "regexva.[0-9]", "regexva.[a-z]" ] ]
			],
			[ "echo", "bar" ],
			[ "echo", "baz" ]
		]
	]
	EOF
	call_json_script "EQVAR=eqval" "REGEXVAR=regexval1"
	assertStdoutEquals "echo bar"
	call_json_script "EQVAR=neq" "REGEXVAR=sxc"
	assertStdoutEquals "echo bar"
	call_json_script "REGEXVAR=sxc"
	assertStdoutEquals "echo bar"
	call_json_script "EQVAR=foo"
	assertStdoutEquals "echo bar"
	call_json_script
	assertStdoutEquals "echo bar"
	call_json_script "EQVAR=eqval" "REGEXVAR=regexval"
	assertStdoutEquals "echo baz"
}

test_expr_isdir() {
	cat >"$JSON_SCRIPT" <<-EOF
	[
		[ "if",
			[ "isdir", "%VAR%" ],
			[ "echo", "bar" ],
			[ "echo", "baz" ]
		]
	]
	EOF
	call_json_script "VAR=/"
	assertStdoutEquals "echo bar"
	call_json_script "VAR=$(mktemp -u)"
	assertStdoutEquals "echo baz"
	call_json_script
	assertStdoutEquals "echo baz"
}

test_cmd_case() {
	cat >"$JSON_SCRIPT" <<-EOF
	[
		[ "case", "CASEVAR", {
			"0": [ "echo", "foo" ],
			"1": [
				[ "echo", "bar" ],
				[ "echo", "baz" ]
			],
			"%VAR%": [ "echo", "quz" ]
		} ]
	]
	EOF
	call_json_script "CASEVAR=0"
	assertStdoutEquals "echo foo"
	call_json_script "CASEVAR=1"
	assertStdoutEquals "echo bar
echo baz"
	call_json_script "CASEVAR=%VAR%"
	assertStdoutEquals "echo quz"
	call_json_script "CASEVAR="
	assertStdoutEquals ""
	call_json_script
	assertStdoutEquals ""
	call_json_script "CASEVAR=xxx" "VAR=xxx"
	assertStdoutEquals ""
}

test_cmd_if() {
	cat >"$JSON_SCRIPT" <<-EOF
	[
		[ "if",
			[ "eq", "VAR", "foo" ],
			[ "echo", "bar" ],
			[ "echo", "baz" ]
		]
	]
	EOF
	call_json_script "VAR=foo"
	assertStdoutEquals "echo bar"
	call_json_script "VAR=xxx"
	assertStdoutEquals "echo baz"
}

test_cmd_cb() {
	cat >"$JSON_SCRIPT" <<-EOF
	[
		[ "exec", "%VAR%", "/%VAS%%%/" ]
	]
	EOF
	call_json_script
	assertStdoutEquals "exec  /%/"
	call_json_script "VAR="
	assertStdoutEquals "exec  /%/"
	call_json_script "VAR=qux" "VAS=3"
	assertStdoutEquals "exec qux /3%/"
}

test_cmd_return() {
	cat >"$JSON_SCRIPT" <<-EOF
	[
		[ "heh", "%HEHVAR%" ],
		[ "%VAR%", "%VAR%" ],
		[ "return" ],
		[ "exec_non_reachable", "Arghhh" ]
	]
	EOF
	call_json_script "HEHVAR=dude" "VAR=ow"
	assertStdoutEquals "heh dude
%VAR% ow"
}

test_jshn_append_no_leading_space() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	# Test appending to empty variable - should not have leading space
	var=''
	_jshn_append var 'foo'
	assertEquals "foo" "$var"

	# Test appending to non-empty variable - should have space separator
	var='bar'
	_jshn_append var 'foo'
	assertEquals "bar foo" "$var"

	# Test multiple appends to empty variable
	var=''
	_jshn_append var 'first'
	_jshn_append var 'second'
	assertEquals "first second" "$var"
}

test_jshn_dump() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	set +u

	json_init

	assertEquals '{ }' "$(json_dump)"

	set -u
}

test_jshn_add_string() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	set +u

	json_init

	json_add_string "name" "joe"

	assertEquals '{ "name": "joe" }' "$(json_dump)"

	set -u
}

test_jshn_add_int() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	set +u

	json_init

	json_add_int "number" 1

	assertEquals '{ "number": 1 }' "$(json_dump)"

	set -u
}

test_jshn_add_boolean() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	set +u

	json_init

	json_add_boolean "done" false

	assertEquals '{ "done": false }' "$(json_dump)"

	set -u
}

test_jshn_add_double() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	set +u

	json_init

	json_add_double "power" 1.605

	assertEquals '{ "power": 1.605 }' "$(json_dump)"

	set -u
}

test_jshn_add_null() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	set +u

	json_init

	json_add_null "reference"

	assertEquals '{ "reference": null }' "$(json_dump)"

	set -u
}

test_jshn_add_object() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	set +u

	json_init

	json_add_object "inventory"

	json_add_int "apples" 61
	json_add_int "pears" 42
	json_add_int "melons" 5

	json_close_object # inventory

	assertEquals '{ "inventory": { "apples": 61, "pears": 42, "melons": 5 } }' "$(json_dump)"

	set -u
}

test_jshn_add_array() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	set +u

	json_init

	json_add_array "interfaces"

	json_add_string "" "eth0"
	json_add_string "" "eth1"
	json_add_string "" "eth2"

	json_close_array # interfaces

	assertEquals '{ "interfaces": [ "eth0", "eth1", "eth2" ] }' "$(json_dump)"

	set -u
}

test_jshn_add_multi() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	set +u

	json_init

	json_add_fields "name:string=joe" "age:int=42" "veteran:boolean=false"

	assertEquals '{ "name": "joe", "age": 42, "veteran": false }' "$(json_dump)"

	set -u
}

test_jshn_append_via_json_script() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	# __SHUNIT_SHELL_FLAGS='u' results in 'line 6: JSON_UNSET: unbound variable' in json_cleanup()
	set +u

	# Test appending first key to empty variable without leading space
	json_init
	json_add_string "first" "value1"
	json_get_keys keys
	assertEquals "first" "$keys"

	# Test appending second key should maintain no leading space on first key
	json_add_string "second" "value2"
	json_get_keys keys
	assertEquals "first second" "$keys"
	set -u
}

test_jshn_get_index() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	set +u

	local index

	json_init

	json_add_object "DHCP4"

	json_add_array "networks"

	json_add_object ""
	json_get_index index
	json_add_int "id" 1
	json_add_string "subnet" "192.168.1.0/24"
	json_close_object

	json_add_object ""
	json_add_int "id" 2
	json_add_string "subnet" "192.168.2.0/24"
	json_close_object

	json_select "$index" # revisit first anonymous object
	json_add_int "valid-lifetime" 3600
	json_select .. # pop back into array

	json_close_array # networks

	json_close_object # DHCP4

	assertEquals '{ "DHCP4": { "networks": [ { "id": 1, "subnet": "192.168.1.0\/24", "valid-lifetime": 3600 }, { "id": 2, "subnet": "192.168.2.0\/24" } ] } }' "$(json_dump)"

	set -u
}

test_jshn_get_root_position() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	# __SHUNIT_SHELL_FLAGS='u' results in 'line 6: JSON_UNSET: unbound variable' in json_cleanup()
	set +u

	local root

	# Test getting the root position
	json_init
	json_add_object "obj"
	json_add_array "arr"
	json_get_root_position root
	assertEquals "J_V" "$root"

	set -u
}

test_jshn_get_parent_position() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	# __SHUNIT_SHELL_FLAGS='u' results in 'line 6: JSON_UNSET: unbound variable' in json_cleanup()
	set +u

	local cur

	json_init

	json_add_object "obj"
	json_add_array "arr"

	local obj="$cur"

	json_get_parent_position cur
	assertEquals "J_T1" "$cur"

	set -u
}

test_jshn_get_position() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	# __SHUNIT_SHELL_FLAGS='u' results in 'line 6: JSON_UNSET: unbound variable' in json_cleanup()
	set +u

	local cur

	# Test getting the root position
	json_init
	json_get_position cur
	assertEquals "J_V" "$cur"

	local root="$cur"

	# ... and the object position
	json_add_object "obj"
	json_get_position cur
	assertEquals "J_T1" "$cur"

	local obj="$cur"

	# ... and the array position
	json_add_array "arr"
	json_get_position cur
	assertEquals "J_A2" "$cur"

	local arr="$cur"

	# ... still within the array
	json_add_string "first" "one"
	json_get_position cur
	assertEquals "J_A2" "$cur"

	# ... still within the array
	json_add_string "second" "two"
	json_get_position cur
	assertEquals "J_A2" "$cur"

	# ... now back to the object
	json_select ..
	json_get_position cur
	assertEquals "$obj" "$cur"

	# ... and at the root
	json_select ..
	json_get_position cur
	assertEquals "$root" "$cur"

	set -u
}

test_jshn_move_to() {
	JSON_PREFIX="${JSON_PREFIX:-}"
	. ../../sh/jshn.sh

	# __SHUNIT_SHELL_FLAGS='u' results in 'line 6: JSON_UNSET: unbound variable' in json_cleanup()
	set +u

	local cur cur2

	json_init
	json_add_object "obj"
	json_get_position cur

	json_add_array "arr"
	json_add_string "first" "one"
	json_add_string "second" "two"

	json_move_to "$cur"

	json_get_position cur2

	assertEquals "J_T1" "$cur2"

	set -u
}

. ./shunit2/shunit2
