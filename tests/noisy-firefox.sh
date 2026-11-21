#!/bin/sh
# A program that starts as Firefox does, then, once it gets the TERM signal, ends at once and leaves a process that
# writes to its output for 8 seconds more: what a Firefox that a loaded machine slows looks like to Ceti.
echo "WebDriver BiDi listening on ws://127.0.0.1:9"
trap '(i=0; while [ $i -lt 40 ]; do echo "a line after the end"; sleep 0.2; i=$((i + 1)); done) & exit 0' TERM
while true; do sleep 0.1; done
