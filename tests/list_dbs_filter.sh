#!/bin/bash

echo "== list_dbs mit Filter gibt nur passende Keys aus =="
CMD="bash mysqlman.sh --config test_mysqlman-connections.yaml list --filter prod.webshop"
echo "> $CMD"
output=$($CMD)
echo "Result:"
echo "$output"
if echo "$output" | grep -q "prod.webshop.winsim" && ! echo "$output" | grep -q "dev.default"; then
  echo OK
else
  echo FAIL
fi