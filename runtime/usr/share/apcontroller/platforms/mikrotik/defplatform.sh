#!/bin/sh

#
# MikroTik platform definition
#

detect()
{
	#
	# RouterOS normally does not expose a normal POSIX shell.
	#
	# We therefore use SSH command behaviour as the detector.
	#

	if command -v /system/resource/print >/dev/null 2>&1; then
		printf '%s\n' "mikrotik"
		return 0
	fi

	#
	# Fallback for RouterOS environments where command -v
	# is not useful.
	#

	if [ -d /flash ] || [ -d /rw/disk ]; then
		:
	fi

	return 1
}
