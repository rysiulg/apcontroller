#!/bin/sh

PATH="/usr/sbin:/usr/bin:/sbin:/bin"

ENGINE_DIR="${ENGINE_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)}"
SCHEMA="${SCHEMA:-$ENGINE_DIR/platforms/openwrt/schema.json}"

TMP="/tmp/apcontroller-engine.$$"

mkdir -p "$TMP" || exit 1
trap 'rm -rf "$TMP"' EXIT INT TERM

###############################################################################
# JSON
###############################################################################

json_escape()
{
	printf '%s' "$1" |
	awk '
		BEGIN { ORS="" }
		{
			gsub(/\\/, "\\\\")
			gsub(/"/, "\\\"")
			gsub(/\t/, "\\t")
			gsub(/\r/, "\\r")
			gsub(/\n/, "\\n")
			printf "%s", $0
		}
	'
}

json_quote()
{
	printf '"'
	json_escape "$1"
	printf '"'
}

json_valid()
{
	[ -n "$1" ] || return 1
	command -v jsonfilter >/dev/null 2>&1 || return 1

	printf '%s\n' "$1" |
		jsonfilter -e '@' >/dev/null 2>&1
}

json_path()
{
	local data="$1"
	local path="$2"

	[ -n "$data" ] || return 1
	[ -n "$path" ] || return 1

	printf '%s\n' "$data" |
		jsonfilter -q -e "@.${path}" 2>/dev/null
}

schema_path()
{
	local path="$1"

	jsonfilter -q -i "$SCHEMA" -e "@.${path}" 2>/dev/null
}

###############################################################################
# VALUE CONVERSION
###############################################################################

emit_typed()
{
	local value="$1"
	local type="$2"

	case "$type" in
		number|int|integer)
			case "$value" in
				''|*[!0-9.-]*)
					printf '0'
					;;
				*)
					printf '%s' "$value"
					;;
			esac
			;;

		boolean|bool)
			case "$value" in
				true|TRUE|1|yes|YES|on|ON)
					printf 'true'
					;;
				*)
					printf 'false'
					;;
			esac
			;;

		object)
			if json_valid "$value"; then
				printf '%s' "$value"
			else
				printf '{}'
			fi
			;;

		array)
			if json_valid "$value"; then
				printf '%s' "$value"
			else
				printf '[]'
			fi
			;;

		json|raw)
			if json_valid "$value"; then
				printf '%s' "$value"
			else
				printf 'null'
			fi
			;;

		*)
			json_quote "$value"
			;;
	esac
}

###############################################################################
# COMMAND + EXTRACT
###############################################################################

run_source()
{
	local command="$1"
	local type="$2"
	local extract="$3"
	local path="$4"

	[ -n "$command" ] || return 1

	local value

	value="$(sh -c "$command" 2>/dev/null)"

	[ -n "$value" ] || return 1

	if [ "$type" = "json" ]; then
		if [ -n "$path" ]; then
			value="$(json_path "$value" "$path")"
		fi
	else
		if [ -n "$extract" ]; then
			value="$(
				printf '%s\n' "$value" |
				sed -nE "s|$extract|\1|p" |
				head -n 1
			)"
		fi
	fi

	[ -n "$value" ] || return 1

	printf '%s' "$value"
	return 0
}

###############################################################################
# GENERIC SOURCE
###############################################################################

field_source()
{
	local base="$1"

	local command
	local type
	local extract
	local path
	local value

	command="$(schema_path "$base.command")"
	type="$(schema_path "$base.type")"
	extract="$(schema_path "$base.extract")"
	path="$(schema_path "$base.path")"

	value="$(run_source "$command" "$type" "$extract" "$path")" &&
	{
		printf '%s' "$value"
		return 0
	}

	#
	# Dowolna liczba fallbacków mogłaby być tu później obsłużona
	# przez sources[]. Obecna wersja zachowuje prosty fallback.
	#
	command="$(schema_path "$base.fallback.command")"
	type="$(schema_path "$base.fallback.type")"
	extract="$(schema_path "$base.fallback.extract")"
	path="$(schema_path "$base.fallback.path")"

	run_source "$command" "$type" "$extract" "$path"
}

###############################################################################
# GENERIC OBJECT MAP
###############################################################################

render_map()
{
	local raw="$1"
	local map_path="$2"

	local result="{"
	local first=1
	local keys
	local key
	local spec
	local type
	local path
	local value
	local nested

	#
	# "*" oznacza: wszystkie klucze obiektu źródłowego.
	#
	if [ "$(schema_path "$map_path.*.type")" = "" ] &&
	   [ "$(schema_path "$map_path.*.path")" = "" ]; then

		keys="$(
			printf '%s\n' "$raw" |
			jsonfilter -q -e '@' 2>/dev/null |
			sed -nE 's/.*"([^"]+)".*/\1/p'
		)"
	else
		keys="$(
			printf '%s\n' "$raw" |
			jsonfilter -q -e '@' 2>/dev/null |
			sed -nE 's/.*"([^"]+)".*/\1/p'
		)"
	fi

	for key in $keys
	do
		spec="$map_path.$key"

		if [ -n "$(schema_path "$map_path.$key.type")" ] ||
		   [ -n "$(schema_path "$map_path.$key.path")" ] ||
		   [ -n "$(schema_path "$map_path.$key.map")" ]
		then
			:
		else
			spec="$map_path.*"
		fi

		type="$(schema_path "$spec.type")"
		path="$(schema_path "$spec.path")"

		#
		# map zagnieżdżony.
		#
		if [ "$type" = "object" ]; then
			value="$(json_path "$raw" "$key")"
			nested="$(render_map "$value" "$spec.map")"

			[ "$first" -eq 0 ] && result="$result,"
			result="$result$(json_quote "$key"):$nested"
			first=0
			continue
		fi

		value="$(json_path "$raw" "$key.$path")"

		[ -n "$value" ] || continue

		[ "$first" -eq 0 ] && result="$result,"

		result="$result$(json_quote "$key"):$(emit_typed "$value" "$type")"
		first=0
	done

	result="$result}"

	printf '%s' "$result"
}

###############################################################################
# OBJECT FIELD
###############################################################################

object_field()
{
	local field_index="$1"
	local command
	local raw
	local map_path

	command="$(schema_path "fields[$field_index].source.command")"

	[ -n "$command" ] || {
		printf '{}'
		return
	}

	raw="$(sh -c "$command" 2>/dev/null)"

	json_valid "$raw" || {
		printf '{}'
		return
	}

	map_path="fields[$field_index].source.map"

	render_map "$raw" "$map_path"
}

###############################################################################
# COLLECTION
###############################################################################

collection_raw()
{
	local collection="$1"
	local command
	local format
	local raw

	command="$(schema_path "collections.${collection}.source.command")"
	format="$(schema_path "collections.${collection}.source.format")"

	[ -n "$command" ] || {
		printf '[]'
		return
	}

	raw="$(sh -c "$command" 2>/dev/null)"

	[ -n "$raw" ] || {
		printf '[]'
		return
	}

	if [ "$format" = "jsonl" ]; then
		printf '%s\n' "$raw" |
			awk '
			BEGIN {
				first=1
				printf "["
			}
			NF {
				if (!first)
					printf ","
				printf "%s", $0
				first=0
			}
			END {
				printf "]"
			}'
		return
	fi

	printf '%s' "$raw"
}




###############################################################################
# COLLECTION ITEM
###############################################################################
schema_object_keys()
{
	local path="$1"
	local raw

	raw="$(schema_path "$path")"

	[ -n "$raw" ] || return 0

	printf '%s\n' "$raw" |
		awk '
		{
			s = $0

			while (match(s, /"[^"]+"[[:space:]]*:[[:space:]]*\{/)) {
				x = substr(s, RSTART, RLENGTH)

				sub(/^"/, "", x)
				sub(/"[[:space:]]*:[[:space:]]*\{$/, "", x)

				print x

				s = substr(s, RSTART + RLENGTH)
			}
		}'
}

render_item()
{
	local item="$1"
	local collection="$2"

	local keys
	local key
	local type
	local source
	local value
	local result="{"
	local first=1

	keys="$(schema_object_keys \
		"collections.$collection.item.fields")"

	for key in $keys
	do
		[ -n "$key" ] || continue

		type="$(schema_path \
			"collections.$collection.item.fields.$key.type")"

		source="$(schema_path \
			"collections.$collection.item.fields.$key.source")"

		[ -n "$type" ] || continue
		[ -n "$source" ] || continue

		value="$(json_path "$item" "$source")"

		[ "$first" -eq 0 ] && result="$result,"

		result="$result$(json_quote "$key"):$(emit_typed "$value" "$type")"

		first=0
	done

	result="$result}"

	printf '%s' "$result"
}


collection_items()
{
	local collection="$1"
	local raw="$2"

	local count
	local i
	local item
	local result="["
	local first=1

	count="$(
		printf '%s\n' "$raw" |
		jsonfilter -q -e '@[*]' 2>/dev/null |
		wc -l |
		tr -d ' '
	)"

	i=0

	while [ "$i" -lt "$count" ]
	do
		item="$(
			printf '%s\n' "$raw" |
			jsonfilter -q -e "@[$i]" 2>/dev/null
		)"

		[ -n "$item" ] || {
			i=$((i + 1))
			continue
		}

		[ "$first" -eq 0 ] && result="$result,"

		result="$result$(render_item "$item" "$collection")"

		first=0
		i=$((i + 1))
	done

	result="$result]"

	printf '%s' "$result"
}

collection_filter()
{
	local raw="$1"
	local field="$2"
	local expected="$3"

	local count
	local i
	local item
	local value
	local result="["
	local first=1

	count="$(
		printf '%s\n' "$raw" |
		jsonfilter -q -e '@[*]' 2>/dev/null |
		wc -l |
		tr -d ' '
	)"

	i=0

	while [ "$i" -lt "$count" ]
	do
		item="$(
			printf '%s\n' "$raw" |
			jsonfilter -q -e "@[$i]" 2>/dev/null
		)"

		if [ -n "$item" ]; then
			value="$(json_path "$item" "$field")"

			if [ "$value" = "$expected" ]; then
				[ "$first" -eq 0 ] && result="$result,"

				result="$result$item"
				first=0
			fi
		fi

		i=$((i + 1))
	done

	result="$result]"

	printf '%s' "$result"
}


###############################################################################
# FIELD
###############################################################################

process_field()
{
	local index="$1"

	local name
	local type
	local default
	local collection
	local filter_field
	local filter_value
	local value

	name="$(schema_path "fields[$index].name")"
	type="$(schema_path "fields[$index].type")"
	default="$(schema_path "fields[$index].default")"

	[ -n "$name" ] || return 1

	#
	# Collection.
	#
	collection="$(schema_path "fields[$index].source.collection")"

	if [ -n "$collection" ]; then

		value="$(collection_raw "$collection")"

		filter_field="$(
			schema_path "fields[$index].source.filter.field"
		)"

		filter_value="$(
			schema_path "fields[$index].source.filter.eq"
		)"

		if [ -n "$filter_field" ] && [ -n "$filter_value" ]; then
			value="$(collection_filter \
				"$value" \
				"$filter_field" \
				"$filter_value")"
		fi

		value="$(collection_items "$collection" "$value")"

		[ -n "$value" ] || value="$default"

		emit_typed "$value" "$type"
		return
	fi

	#
	# Object.
	#
	if [ "$type" = "object" ]; then
		object_field "$index"
		return
	fi

	#
	# Zwykłe pole.
	#
	value="$(field_source "fields[$index].source")"

	[ -n "$value" ] || value="$default"

	emit_typed "$value" "$type"
}

###############################################################################
# POLL
###############################################################################

apc_engine_poll()
{
	[ -r "$SCHEMA" ] || {
		printf '{"error":"schema_not_found"}\n'
		return 1
	}

	command -v jsonfilter >/dev/null 2>&1 || {
		printf '{"error":"jsonfilter_not_found"}\n'
		return 1
	}

	local count
	local i
	local name
	local value
	local result="{"
	local first=1

count=0

while :
do
	name="$(jsonfilter -q -i "$SCHEMA" -e "@.fields[$count].name" 2>/dev/null)"

	[ -n "$name" ] || break

	count=$((count + 1))
done

[ "$count" -gt 0 ] || {
	printf '{"error":"schema_fields_missing"}\n'
	return 1
}


	i=0

	while [ "$i" -lt "$count" ]
	do
		name="$(schema_path "fields[$i].name")"

		[ -n "$name" ] || {
			i=$((i + 1))
			continue
		}

		value="$(process_field "$i")"

		[ -n "$value" ] || value="null"

		[ "$first" -eq 0 ] && result="$result,"

		result="$result$(json_quote "$name"):$value"

		first=0
		i=$((i + 1))
	done

	result="$result}"

	if json_valid "$result"; then
		printf '%s\n' "$result"
	else
		printf '{"error":"engine_invalid_output"}\n'
		return 1
	fi
}
