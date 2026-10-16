# Attended upgrade and SSTP dependency (r33)

The firmware builder must omit both the local SSTP client and `luci-proto-sstp`. Omitting only `sstp-client` is insufficient: the retained LuCI protocol package requests the official SSTP package transitively. The affected official build includes `/etc/ppp/chap-secrets`, also owned by `ppp`, and the APK installation fails.

The ASU integration now removes eight known packages from the remote image request, retains ordinary firmware/kernel dependencies, and reinstalls the custom applications, signed local SSTP client and LuCI SSTP protocol from the configured feeds after boot. It upgrades an existing integration block in place and does not duplicate its notice. It does not force file overwrites or change the ownership of PPP authentication files.

The modified ASU LuCI file remains explicitly covered by sysupgrade backup because it is a justified local adaptation of a system package. Private configuration, the public feed verification key and custom repository path remain covered as before. The local SSTP package and its signing key are unchanged. Reopen or hard-refresh the attended-upgrade page before requesting a new image; an already submitted request keeps its old package list.

No firmware flash or router restart is performed by this fix. Verify the request excludes `luci-proto-sstp` as well as all seven prior custom names. Package restoration requires the feed and WAN to be available after boot; review the bootstrap log if that step fails.
