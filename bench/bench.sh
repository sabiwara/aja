#!/bin/bash

set -o errexit

tmp_file="/tmp/bench"

MIX_ENV=bench mix compile

runfile() {
  file="${1}"
  results_file="${file%.exs}.results.txt"

  MIX_ENV=bench mix run "${file}" | tee "${tmp_file}"
  cp "${tmp_file}" "${results_file}"
}

if [ -d "${1}" ] ; then
  files=$(find "${1}" -path "**/*.exs")
  for file in $files; do (runfile $file); done
  exit 0
fi

if [ -f "${1}" ] ; then
  runfile "${1}"
  exit 0
fi

echo "File does not exist: '${file}'"
exit 1
