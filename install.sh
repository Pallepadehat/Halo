#!/bin/bash
# Installs Halo Helper, the Mac half of Halo.
#
#   curl -fsSL https://raw.githubusercontent.com/Pallepadehat/Halo/main/install.sh | bash
#
# It downloads the latest HaloHelper.dmg from GitHub Releases, puts the app in /Applications
# (replacing an older copy) and opens it. It also clears the "downloaded from the internet" flag, so
# even a disk image built without notarization opens without a warning.
#
# Options (after `bash -s --` when piping):
#   path/to/HaloHelper.dmg   install from a .dmg you already have instead of downloading
#   --no-open                don't open the app afterwards
#
# HALO_INSTALL_DIR overrides /Applications; HALO_DMG_URL overrides where the .dmg comes from.
#
# Everything runs inside main(), so a download cut off half way can't run half a script.

set -euo pipefail

# Global, not local to main(): the clean-up below runs after main() has returned.
tmp=""

say() { printf '\033[1m◎ %s\033[0m\n' "$*"; }
die() { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

main() {
  local repo="Pallepadehat/Halo"
  local url="${HALO_DMG_URL:-https://github.com/${repo}/releases/latest/download/HaloHelper.dmg}"
  local dest="${HALO_INSTALL_DIR:-/Applications}"
  local app="Halo Helper.app"
  local bundle_id="dk.patrickjak.halo.mac"
  local open_after=1 dmg=""

  for arg in "$@"; do
    case "${arg}" in
      --no-open) open_after=0 ;;
      -h | --help) sed -n '2,17p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 0 ;;
      *.dmg) dmg="${arg}" ;;
      *) die "Unknown option: ${arg}" ;;
    esac
  done

  [[ "$(uname -s)" == "Darwin" ]] || die "Halo Helper is a Mac app."
  local major
  major="$(sw_vers -productVersion | cut -d. -f1)"
  (( major >= 26 )) || die "Halo Helper needs macOS 26 or later (you have $(sw_vers -productVersion))."

  tmp="$(mktemp -d)"
  # Clean up however it ends, keeping the real exit status.
  trap 'status=$?; hdiutil detach "$tmp/mount" -quiet -force >/dev/null 2>&1 || true; rm -rf "$tmp"; exit $status' EXIT

  if [[ -z "${dmg}" ]]; then
    say "Downloading Halo Helper…"
    curl -fL --progress-bar "${url}" -o "$tmp/HaloHelper.dmg" \
      || die "Couldn't download ${url}. Is there a release with HaloHelper.dmg attached?"
    dmg="$tmp/HaloHelper.dmg"
  fi
  [[ -f "${dmg}" ]] || die "No such file: ${dmg}"

  hdiutil attach "${dmg}" -nobrowse -readonly -noautoopen -mountpoint "$tmp/mount" -quiet \
    || die "Couldn't open the disk image."
  [[ -d "$tmp/mount/${app}" ]] || die "The disk image doesn't have ${app} in it."

  # An older helper has to quit before the new one moves in.
  if pgrep -x "Halo Helper" >/dev/null; then
    say "Quitting the running Halo Helper…"
    osascript -e "tell application id \"$bundle_id\" to quit" >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x "Halo Helper" >/dev/null || break; sleep 0.5; done
    pkill -x "Halo Helper" 2>/dev/null || true
  fi

  say "Installing to ${dest}…"
  # Runs as you, or with sudo when the folder isn't yours to write (an empty array trips bash 3.2's `set -u`).
  local use_sudo=""
  if [[ -e "${dest}/${app}" && ! -w "${dest}/${app}" ]] || { [[ -d "${dest}" ]] && [[ ! -w "${dest}" ]]; }; then
    say "${dest} needs your password."
    use_sudo=1
  fi
  run() { if [[ -n "$use_sudo" ]]; then sudo "$@"; else "$@"; fi; }
  run mkdir -p "${dest}"
  run rm -rf "${dest}/${app}"
  run ditto "$tmp/mount/${app}" "${dest}/${app}"
  # Releases are notarized, but a disk image made without it would be blocked while it carries the download flag.
  run xattr -dr com.apple.quarantine "${dest}/${app}" 2>/dev/null || true

  say "Halo Helper is installed in ${dest}."
  if (( open_after )); then
    open "${dest}/${app}"
    say "It's in your menu bar now: the ◎. Open Halo on your iPad to pair."
  fi
}

main "$@"
