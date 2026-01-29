#!/bin/bash

echo "== get_dsn_val extrahiert user korrekt =="
CMD="bash -c 'source mysqlman.sh; get_dsn_val \"mysql://foo:bar@host:3306/db\" \"user\"'"
echo "> $CMD"
user=$(eval $CMD)
echo "Result: $user"
if [ "$user" = "foo" ]; then
  echo OK
else
  echo FAIL
fi
