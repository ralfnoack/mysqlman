#!/bin/bash

echo "== get_target_dbs mit nicht existierendem Key gibt nichts aus =="
CMD="bash -c 'source mysqlman.sh; get_target_dbs arr \"notfound\"'"
echo "> $CMD"
res=$(eval $CMD)
echo "Result: $res"
if [ -z "$res" ]; then
  echo OK
else
  echo FAIL
fi
