# Repository secrets

The unencrypted legacy EC signing key at `keys/apcontroller.rsa` was present in the old Git history. It must be considered exposed, even after history removal. It is not the public key currently used by the local APK feed. Do not trust signatures made with the legacy key or reuse it for new releases.

The affected path has been removed from the repository history. Commit and tag IDs changed. Existing clones must not merge or push the old history back. Preserve private local changes separately and make a fresh clone, then reapply only the reviewed source changes. Do not upload Git bundles made from old clones.

Private signing material belongs outside the public repository and WWW tree. Public verification keys may be published. `.gitignore` prevents common key paths from being newly added; it cannot remove files already committed. CI scans the full checked-out history with checksum-verified Gitleaks and redacts findings from logs. To enable the local known-history guard, run `git config core.hooksPath .githooks`.

History removal cannot revoke a key, remove other users' clones or erase cached commit views. Copies in upstream repositories and GitHub cached/PR references may require action by their owner or GitHub Support. This change does not rotate router credentials or the current APK signing key.
