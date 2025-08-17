#!/bin/sh
# Print "SSO" and exit 0 if any AWS SSO cached token is still valid; otherwise exit 1.
# Portable for macOS (BSD date) and Linux (GNU date).

set -eu

cache_dir="$HOME/.aws/sso/cache"
[ -d "$cache_dir" ] || exit 1

now_epoch=$(date -u +%s)

# Try to parse an ISO8601 timestamp into epoch seconds in a portable way
iso_to_epoch() {
	# Normalize Z to +00:00 and remove colon in offset for BSD date
	val=$1
	val=$(printf %s "$val" | sed -E 's/Z$/+00:00/; s/([+-][0-9]{2}):([0-9]{2})/\1\2/')
	# macOS: date -j -f ... ; Linux: date -d ...
	if epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%S%z" "$val" +%s 2>/dev/null); then
		printf %s "$epoch"
		return 0
	fi
	if epoch=$(date -u -d "$val" +%s 2>/dev/null); then
		printf %s "$epoch"
		return 0
	fi
	return 1
}

for json_file in "$cache_dir"/*.json; do
	[ -e "$json_file" ] || break
	# Extract expiration timestamp (supports both expiresAt and expiration)
	exp_ts=$(jq -r '(.expiresAt // .expiration // empty)' "$json_file" 2>/dev/null || true)
	[ -n "$exp_ts" ] || continue
	if epoch=$(iso_to_epoch "$exp_ts"); then
		if [ "$epoch" -gt "$now_epoch" ]; then
			printf %s "SSO"
			exit 0
		fi
	fi
done

exit 1
