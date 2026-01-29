list_dbs() {
  local filter="$1"
  local idx=1
  printf "%-3s | %-30s | %-16s | %-25s | %-6s | %-20s\n" "ID" "Key" "User" "Host" "Port" "Database"
  printf "%s\n" "-------------------------------------------------------------------------------------------------------------"
  db_keyval_list | while IFS='=' read -r key dsn; do
    key="${key// /}"
    dsn="${dsn## }"
    user=$(get_dsn_val "$dsn" "user")
    host=$(get_dsn_val "$dsn" "host")
    port=$(get_dsn_val "$dsn" "port")
    db=$(get_dsn_val "$dsn" "database")
    user=${user:-"-"}
    host=${host:-"-"}
    port=${port:-"3306"}
    db=${db:-"-"}
    match=1
    if [[ -n "$filter" ]]; then
      [[ "$key" == $filter* ]] || match=0
    fi
    if [[ "$match" -eq 1 ]]; then
      printf "%-3s | %-30s | %-16s | %-25s | %-6s | %-20s\n" "$idx" "$key" "$user" "$host" "$port" "$db"
      idx=$((idx + 1))
    fi
  done
}
