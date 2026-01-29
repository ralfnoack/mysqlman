#!/bin/bash

# Check for mariadb or mysql client dependency
if command -v mariadb.exe >/dev/null 2>&1; then
  MYSQL_EXEC="mariadb.exe"
elif command -v mysql.exe >/dev/null 2>&1; then
  MYSQL_EXEC="mysql.exe"
elif command -v mariadb >/dev/null 2>&1; then
  MYSQL_EXEC="mariadb"
elif command -v mysql >/dev/null 2>&1; then
  MYSQL_EXEC="mysql"
else
  echo -e "\033[31mERROR:\033[0m Neither mariadb nor mysql client is installed or in \$PATH." >&2
  echo "Please install mariadb-client or mysql-client and ensure it is in your PATH." >&2
  exit 1
fi
# Check for yq dependency
if command -v yq.exe >/dev/null 2>&1; then
  YQ_EXEC="yq.exe"
elif command -v yq >/dev/null 2>&1; then
  YQ_EXEC="yq"
else
  echo -e "\033[31mERROR:\033[0m yq is not installed or in \$PATH." >&2
  echo "Please install yq and ensure it is in your PATH." >&2
  exit 1
fi

# MySQL/MariaDB CLI Tool: YAML config + DSN + filter + dry-run support
# Dependencies: yq (https://github.com/mikefarah/yq), mariadb or mysql client

CONFIG_FILE="mysqlman-connections.yaml"
LOG_FILE="mysqlman.log"
mkdir -p logs

# Parse global flags for config and log file override
while [[ "$1" =~ ^--(config|log)$ ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="$2"; shift 2;;
    --log)
      LOG_FILE="$2"; shift 2;;
  esac
done

usage() {
  cat <<EOF
Usage: $0 <command> [options]
 
Commands:
  list [--filter key=value]
      List configured databases, optionally filtering by a field.
  query [--query SQL | --query-file FILE | --query-name QUERY_NAME] [--db names] [--filter key=value] [--dry-run] [--debug]
       Execute a query on specified databases (by names or filtered). Specify single or multiple databases by repeating the --db flag (do not use comma-separated lists). Query can be from the command line, a file, or picked from mysqlman-queries.yaml by name. Use --dry-run to preview. Use --debug to print the exact command(s) run (passwords masked). Uses 'mariadb' executable if available, else falls back to 'mysql'. If you see SSL certificate errors and are running in a test/dev environment, SSL server cert verification is disabled by default (--ssl-verify-server-cert=off).
  help
      Show this help message.
 
Examples:
  mysqlman.sh list --filter host=localhost
  mysqlman.sh query --query "SELECT * FROM users;" --filter host=devhost
  mysqlman.sh query --query-name get_all_users --db production
  mysqlman.sh query --query-file q.sql --db prod --db dev --dry-run

EOF
}

# Extract DSN details under key (field)

get_dsn_val() {
  local dsn="$1"
  local key="$2"
  case "$key" in
    user) echo "$dsn" | sed -nE 's|mysql://([^:@/]+)(:[^@]*)?@.*|\1|p' ;;
    password) echo "$dsn" | sed -nE 's|mysql://[^:/@]+:([^@]*)@.*|\1|p' ;;
    host) echo "$dsn" | sed -nE 's|mysql://[^@]+@([^:/@]+)(:[0-9]+)?/.*|\1|p' ;;
    port) echo "$dsn" | sed -nE 's|mysql://[^@]+@[^:/@]+:([0-9]+).*|\1|p' ;;
    database) echo "$dsn" | sed -nE 's|mysql://[^@]+@[^:/@]+(:[0-9]+)?/([^/?&#]*)?.*|\2|p' ;;
    *) echo ;; # not supported
  esac
}

# Gibt alle Dot-Notation-Schlüssel und DSN-Werte als Zeilen "key = dsn" aus
db_keyval_list() {
  "$YQ_EXEC" '.databases' -op "$CONFIG_FILE"
}

# Listet alle Verbindungen, optional gefiltert nach Dot-Notation-Präfix
list_dbs() {
  local filter="$1"
  local idx=1
  printf "%-3s | %-30s | %-16s | %-25s | %-6s | %-20s\n" "ID" "Key" "User" "Host" "Port" "Database"
  printf "%s\n" "-------------------------------------------------------------------------------------------------------------"
  db_keyval_list | while IFS='=' read -r key dsn; do
    key="${key// /}" # Leerzeichen entfernen
    dsn="${dsn## }"  # führende Leerzeichen entfernen
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

# Gibt alle passenden key/dsn-Zeilen für --db oder --filter zurück
get_target_dbs() {
  local -n dbnames_arr_ref="$1"
  local filter="$2"
  if [[ ${#dbnames_arr_ref[@]} -gt 0 ]]; then
    for dbn in "${dbnames_arr_ref[@]}"; do
      db_keyval_list | while IFS='=' read -r key dsn; do
        key="${key// /}"
        dsn="${dsn## }"
        if [[ "$key" == "$dbn" ]]; then
          echo "$key = $dsn"
        fi
      done
    done
  elif [[ -n "$filter" ]]; then
    db_keyval_list | while IFS='=' read -r key dsn; do
      key="${key// /}"
      dsn="${dsn## }"
      [[ "$key" == $filter* ]] && echo "$key = $dsn"
    done
  else
    db_keyval_list
  fi
}

# Query-Durchführung angepasst auf key = dsn-Zeilen
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
    echo "$targets"
    echo "$targets" | while IFS='=' read -r key dsn; do
      key="${key// /}"
      dsn="${dsn## }"
      user=$(get_dsn_val "$dsn" "user")
      host=$(get_dsn_val "$dsn" "host")
      port=$(get_dsn_val "$dsn" "port")
      db=$(get_dsn_val "$dsn" "database")
      if [[ $mask_pw -eq 1 ]]; then
        dsn_masked=$(echo "$dsn" | sed -E 's|(mysql://[^:]+:)[^@]+(@.*)|\1*****\2|')
        echo "- $key: $dsn_masked"
      else
        echo "- $key: $dsn"
      fi
      if [[ "$debug" == 1 ]]; then
        cmd="$MYSQL_EXEC -h $host -P ${port:-3306} -u $user -p***** $db -e \"$sql\" --ssl-verify-server-cert=off"
        echo "[DEBUG] Would run: $cmd"
      fi
    done
    echo -e "\nQuery to run:"
    echo "$sql"
    return 0
  fi
  echo "$targets" | while IFS='=' read -r key dsn; do
    key="${key// /}"
    dsn="${dsn## }"
    user=$(get_dsn_val "$dsn" "user")
    host=$(get_dsn_val "$dsn" "host")
    port=$(get_dsn_val "$dsn" "port")
    db=$(get_dsn_val "$dsn" "database")
    echo "========= $key ========="
    if [[ "$debug" == 1 ]]; then
      cmd="$MYSQL_EXEC -h $host -P ${port:-3306} -u $user -p***** $db -e \"$sql\" --ssl-verify-server-cert=off"
      echo "[DEBUG] Running: $cmd"
    fi
    "$MYSQL_EXEC" -h "$host" -P "${port:-3306}" -u "$user" -p"$(get_dsn_val "$dsn" "password")" "$db" -e "$sql" --ssl-verify-server-cert=off 2>&1 | tee -a "$LOG_FILE"
    echo
  done
}

# Main
case "$1" in
  list)
    shift
    filter=
    while [[ "$1" ]]; do
      case "$1" in
        --filter) filter="$2"; shift 2;;
        --db)
          echo "Error: --db is not supported for the list command. Use it only with 'query'."
          exit 1;;
        --databases)
          echo "Error: --databases flag has been renamed to --db. Use --db instead."
          exit 1;;
        *) shift;;
      esac
    done
    list_dbs "$filter"
    ;;
  query)
    shift
    sql=""
    sqlfile=""
    queryname=""
    dbnames_arr=()
    filter=""
    dryrun=0
    debug=0
    while [[ "$1" ]]; do
      case "$1" in
        --query) sql="$2"; shift 2;;
        --query-file) sqlfile="$2"; shift 2;;
        --query-name) queryname="$2"; shift 2;;
        --db)
          if [[ "$2" == *,* ]]; then
            echo "Error: Do not use comma-separated lists for database names. Use multiple --db flags instead."
            exit 1
          fi
          dbnames_arr+=("$2")
          shift 2;;
        --filter) filter="$2"; shift 2;;
        --dry-run) dryrun=1; shift;;
        --debug) debug=1; shift;;
        *) shift;;
      esac
    done
    # Conflict check
    if [[ -n "$queryname" && ( -n "$sql" || -n "$sqlfile" ) ]]; then
      echo "Error: --query-name cannot be combined with --query or --query-file."; exit 1;
    fi
    if [[ -n "$sqlfile" ]]; then
      sql="$(cat "$sqlfile")"
    fi
    if [[ -n "$queryname" ]]; then
      if [[ ! -f "mysqlman-queries.yaml" ]]; then
        echo "Error: mysqlman-queries.yaml not found."; exit 1;
      fi
      sql=$("$YQ_EXEC" ".queries[] | select(.name == \"$queryname\") | .query" mysqlman-queries.yaml)
      # Remove surrounding single/double quotes (if any) and trim whitespace
      sql="$(echo "$sql" | sed -E 's/^\s*["'\'']?([^"'\''].*[^"'\''])["'\'']?\s*$/\1/' | sed 's/^ *//;s/ *$//')"
      if [[ -z "$sql" || "$sql" == "null" ]]; then
        echo "Error: Query named '$queryname' not found in mysqlman-queries.yaml."; exit 1;
      fi
    fi
    if [[ -z "$sql" ]]; then
      echo "Query required (use --query, --query-file, or --query-name)."; exit 1;
    fi
    # Pass "--unmasked" if user provided explicitly
    maskflag=""
    for arg in "$@"; do
      [[ "$arg" == "--unmasked" ]] && maskflag="--unmasked"
    done
    query_dbs "$sql" dbnames_arr "$filter" "$dryrun" $maskflag "$debug"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command. Use '$0 help' for usage."
    usage
    exit 1
    ;;
esac
