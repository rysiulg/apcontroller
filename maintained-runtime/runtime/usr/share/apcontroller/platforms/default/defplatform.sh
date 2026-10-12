#!/bin/sh

#
# APController platform definition
#
#
# Generic/default platform.
#
# This must NEVER claim a device during automatic detection.
#

detect()
{
	#
	# This function is extracted and executed remotely.
	#
	# It MUST print something only when this platform
	# is detected.
	#

	# detection code later
    return 1
}

detect_local()
{
	#
	# Optional local detector.
	#
	# Return/print anything only when platform matches.
	#
    return 1
}
