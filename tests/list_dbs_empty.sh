#!/bin/bash

echo "== list_dbs mit leerer Konfiguration gibt keine Zeilen aus =="
CMD="bash mysqlman.sh --config test_mysqlman-connections_empty.yaml list"
echo "> $CMD"
output=$($CMD)
echo "Result:"
echo "$output"
if ! echo "$output" | grep -q "="; then
  echo OK
else
  echo FAIL
fi