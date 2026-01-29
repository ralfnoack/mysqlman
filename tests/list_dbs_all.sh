#!/bin/bash

echo "== list_dbs gibt alle Verbindungen ohne Filter korrekt aus =="
YQ_EXEC=yq
export YQ_EXEC
CMD="bash mysqlman.sh --config test_mysqlman-connections.yaml list"
echo "> $CMD"
output=$($CMD)
echo "Result:"
echo "$output"
if echo "$output" | grep -q "prod.webshop.winsim" && echo "$output" | grep -q "dev.default"; then
  echo OK
else
  echo FAIL
fi