#!/bin/sh
# The site of Ceti as cesia doc --site makes it: its book, and the reference of its package under the name a program
# writes, deps/www-celestial/ceti/src/browser. The book's examples use the package as a program does, so the site is built
# from a project of its own that holds the package in deps/ as cesia pkg puts it; they are norun: the site starts no
# Firefox.
#   tools/site.sh FOLDER     writes the site in FOLDER, with the cesia of the PATH
set -eu
cd "$(dirname "$0")/.."
root=$PWD
mkdir -p "$1"
out=$(cd "$1" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp -R docs "$work/"
cp README.md README.fr.md "$work/"
dep=$work/deps/www-celestial/ceti
mkdir -p "$dep/src"
cp cesia.toml "$dep/"
cp -R src/browser "$dep/src/"
{
  printf '[project]\nname = "ceti-site"\nsrc = []\n\n[deps.ceti]\nfrom = "github.com/www-celestial/ceti"\n'
  printf 'version = "v0.1.0"\ntake = ["src/browser"]\n\n'
  sed -n '/^\[site\]$/,$p' cesia.toml
} > "$work/cesia.toml"
cd "$work"
cesia run --allow read,write "$root/tools/lock.ce"
cesia doc --site "$out"
# The reference links each name to its line in this repository, where the package is src/browser, not deps/...
find "$out/ref" -name '*.html' -exec sed -i 's#/blob/main/deps/www-celestial/ceti/#/blob/main/#g' {} +
