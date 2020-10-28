#!/bin/sh

set -o errexit

file="${1}"
tmp_file="/tmp/bench"

if [ ! -f "$file" ] ; then
  echo "File does not exist: '${file}'"
  exit 0
fi

results_file="${file%.exs}.results.txt"

MIX_ENV=bench mix run "${file}" | tee "${tmp_file}"
cp "${tmp_file}" "${results_file}"
