#!/bin/bash

echo "== query_dbs dry-run gibt DSN maskiert aus =="
CMD="bash mysqlman.sh --config test_mysqlman-connections.yaml query --query 'SELECT 1;' --db prod.webshop.winsim --dry-run"
echo "> $CMD"
output=$(eval $CMD)
echo "Result:"
echo "$output"
if echo "$output" | grep -q "prod.webshop.winsim" && echo "$output" | grep -q '\*\*\*\*\*'; then
  echo OK
else
  echo FAIL
fi