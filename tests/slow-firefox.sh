#!/bin/sh
# Firefox, as on a loaded machine: once it has ended, its process takes 6 seconds more to end, its output open.
case "$1" in
  --full-version) exec firefox "$@" ;;
esac
firefox "$@"
code=$?
sleep 6
exit $code
