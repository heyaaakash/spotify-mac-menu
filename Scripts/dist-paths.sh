#!/bin/zsh
# Source after changing to the repository root. Shared release and media paths.
version="$(<VERSION)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION" >&2; exit 1; }
architecture="${SPOTMENU_ARCH:-$(uname -m)}"
[[ "$architecture" == arm64 || "$architecture" == x86_64 ]] || { echo "Unsupported SPOTMENU_ARCH: $architecture" >&2; exit 1; }
# An alternate root allows isolated verification without replacing local releases.
spotmenu_dist_root="${SPOTMENU_DIST_ROOT:-${PWD}/dist}"
spotmenu_dist_root="${spotmenu_dist_root:A}"
version_dir="${spotmenu_dist_root}/${version}"
app_dir="${version_dir}/apps/${architecture}"
app="${app_dir}/SpotMenu.app"
packages_dir="${version_dir}/packages"
release_dir="${version_dir}/release"
# Promotional and other non-release outputs are independent of app versions.
media_dir="${spotmenu_dist_root}/media"
other_dir="${spotmenu_dist_root}/other"
