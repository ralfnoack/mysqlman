query_dbs() {
  local sql="$1"
  local dbnames_arr_ref="$2"
  local filter="$3"
  local dryrun="$4"
  local maskflag="$5"
  local debug="$6"
  local targets
  targets=$(get_target_dbs "$dbnames_arr_ref" "$filter")
  if [[ -z "$targets" ]]; then
    echo "No matching databases found."
    exit 2
  fi
  if [[ "$dryrun" == 1 ]]; then
    local mask_pw=1
    [[ "$5" == "--unmasked" ]] && mask_pw=0
    echo "[DRY RUN] Would execute query on the following databases:"
    while read -r key dsn; do
      user=$(get_dsn_val "$dsn" "user")
      host=$(get_dsn_val "$dsn" "host")
      port=$(get_dsn_val "$dsn" "port")
      db=$(get_dsn_val "$dsn" "database")
      dsn_out="$dsn"
      [[ $mask_pw -eq 1 ]] && dsn_out=$(echo "$dsn" | sed -E 's|(mysql://[^:]+:)[^@]+(@.*)|\1*****\2|')
      echo "- $key: $dsn_out"
      if [[ "$debug" == 1 ]]; then
        cmd="$MYSQL_EXEC -h $host -P ${port:-3306} -u $user"
        [[ -n "$(get_dsn_val "$dsn" "password")" ]] && cmd="$cmd -p*****"
        cmd="$cmd $db -e \"$sql\" --ssl-verify-server-cert=off"
        echo "[DEBUG] Would run: $cmd"
      fi
    done <<< "$targets"
    echo -e "\nQuery to run:\n$sql"
    return 0
  fi
  while read -r key dsn; do
    user=$(get_dsn_val "$dsn" "user")
    host=$(get_dsn_val "$dsn" "host")
    port=$(get_dsn_val "$dsn" "port")
    db=$(get_dsn_val "$dsn" "database")
    echo "========= $key ========="
    if [[ "$debug" == 1 ]]; then
      cmd="$MYSQL_EXEC -h $host -P ${port:-3306} -u $user"
      [[ -n "$(get_dsn_val "$dsn" "password")" ]] && cmd="$cmd -p*****"
      cmd="$cmd $db -e \"$sql\" --ssl-verify-server-cert=off"
      echo "[DEBUG] Running: $cmd"
    fi
    "$MYSQL_EXEC" -h "$host" -P "${port:-3306}" -u "$user" -p"$(get_dsn_val "$dsn" "password")" "$db" -e "$sql" --ssl-verify-server-cert=off 2>&1 | tee -a "$LOG_FILE"
    echo
  done <<< "$targets"
}
