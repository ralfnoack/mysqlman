#!/bin/bash

echo "== get_dsn_val extrahiert host korrekt =="
CMD="bash -c 'source mysqlman.sh; get_dsn_val \"mysql://foo:bar@host:3306/db\" \"host\"'"
echo "> $CMD"
host=$(eval $CMD)
echo "Result: $host"
if [ "$host" = "host" ]; then
  echo OK
else
  echo FAIL
fi
