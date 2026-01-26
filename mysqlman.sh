#!/bin/bash

# Check for mariadb or mysql client dependency
if command -v mariadb >/dev/null 2>&1; then
  MYSQL_EXEC="mariadb"
elif command -v mysql >/dev/null 2>&1; then
  MYSQL_EXEC="mysql"
else
  echo -e "\033[31mERROR:\033[0m Neither mariadb nor mysql client is installed or in \$PATH." >&2
  echo "Please install mariadb-client or mysql-client and ensure it is in your PATH." >&2
  exit 1
fi

# MySQL/MariaDB CLI Tool: YAML config + DSN + filter + dry-run support
# Dependencies: yq (https://github.com/mikefarah/yq), mariadb or mysql client

CONFIG_FILE="mysqlman-connections.yaml"
LOG_FILE="logs/execution.log"
mkdir -p logs

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
    host) echo "$dsn" | sed -nE 's|mysql://[^@]+@([^:/@]+).*|\1|p' ;;
    port) echo "$dsn" | sed -nE 's|mysql://[^@]+@[^:/@]+:([0-9]+).*|\1|p' ;;
    database) echo "$dsn" | sed -nE 's|mysql://[^@]+@[^:/@]+(:[0-9]+)?/([^/?&#]*)?.*|\2|p' ;;
    *) echo ;; # not supported
  esac
}

# Filter databases by key=value.
filter_dbs() {
  local filter="$1"
  if [[ -z "$filter" ]]; then
    yq '.databases[]' "$CONFIG_FILE"
  else
    local key="$(echo "$filter" | awk -F= '{print $1}')"
    local value="$(echo "$filter" | awk -F= '{print $2}')"
    yq ".databases[] | select(.dsn | test('$key=[^&@:/]*$value'))" "$CONFIG_FILE"
  fi
}

# List databases, optionally filtered
list_dbs() {
  local filter="$1"
  local filter_key=""
  local filter_value=""
  if [[ -n "$filter" ]]; then
    filter_key="$(echo "$filter" | cut -d= -f1)"
    filter_value="$(echo "$filter" | cut -d= -f2-)"
  fi
  local idx=1
   printf "%-3s | %-13s | %-16s | %-6s | %-10s | %-12s\n" "ID" "Name" "User" "Host" "Port" "Database"
   printf "%s\n" "-------------------------------------------------------------------------------"
   yq -c '.databases[]' "$CONFIG_FILE" | while read -r row; do
     name=$(echo "$row" | jq -r '.name')
     dsn=$(echo "$row" | jq -r '.dsn')
     user=$(get_dsn_val "$dsn" user)
     host=$(get_dsn_val "$dsn" host)
     port=$(get_dsn_val "$dsn" port)
     db=$(get_dsn_val "$dsn" database)
    match=1
    if [[ -n "$filter_key" && -n "$filter_value" ]]; then
      case "$filter_key" in
        name)
          [[ "$name" == *"$filter_value"* ]] || match=0
          ;;
        host)
          [[ "$host" == *"$filter_value"* ]] || match=0
          ;;
        port)
          [[ "$port" == *"$filter_value"* ]] || match=0
          ;;
        database)
          [[ "$db" == *"$filter_value"* ]] || match=0
          ;;
        *)
          match=0 ;;
      esac
    elif [[ -n "$filter_value" ]]; then
      if [[ "$name" == *"$filter_value"* || "$dsn" == *"$filter_value"* ]]; then
        match=1
      else
        match=0
      fi
    fi
     if [[ "$match" -eq 1 ]]; then
       printf "%-3s | %-13s | %-16s | %-6s | %-10s | %-12s\n" "$idx" "$name" "$user" "$host" "${port:-3306}" "$db"
       idx=$((idx + 1))
     fi
  done
}

# Find databases by array of names and/or robust field filter
get_target_dbs() {
  local -n dbnames_arr_ref="$1"
  local filter="$2"
  # Use bash-level robust filtering as in list_dbs
  if [[ ${#dbnames_arr_ref[@]} -gt 0 ]]; then
    yq -c '.databases[]' "$CONFIG_FILE" | while read -r row; do
      name=$(echo "$row" | jq -r '.name')
      for dbn in "${dbnames_arr_ref[@]}"; do
        if [[ "$name" == "$dbn" ]]; then
          echo "$row"
        fi
      done
    done
  elif [[ -n "$filter" ]]; then
    filter_key="$(echo "$filter" | cut -d= -f1)"
    filter_value="$(echo "$filter" | cut -d= -f2-)"
    yq -c '.databases[]' "$CONFIG_FILE" | while read -r row; do
      name=$(echo "$row" | jq -r '.name')
      dsn=$(echo "$row" | jq -r '.dsn')
      host=$(get_dsn_val "$dsn" host)
      port=$(get_dsn_val "$dsn" port)
      db=$(get_dsn_val "$dsn" database)
      match=1
      case "$filter_key" in
        name) [[ "$name" == *"$filter_value"* ]] || match=0;;
        host) [[ "$host" == *"$filter_value"* ]] || match=0;;
        port) [[ "$port" == *"$filter_value"* ]] || match=0;;
        database) [[ "$db" == *"$filter_value"* ]] || match=0;;
        *) match=0;;
      esac
      if [[ "$match" -eq 1 ]]; then
        echo "$row"
      fi
    done
  else
    yq -c '.databases[]' "$CONFIG_FILE"
  fi
}


# Query databases (takes SQL, dbnames, and/or filter, dryrun flag)
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
    echo "$targets" | while read -r row; do
      name=$(echo "$row" | jq -r '.name')
      dsn=$(echo "$row" | jq -r '.dsn')
      host=$(get_dsn_val "$dsn" host)
      port=$(get_dsn_val "$dsn" port)
      user=$(get_dsn_val "$dsn" user)
      pass=$(get_dsn_val "$dsn" password)
      db=$(get_dsn_val "$dsn" database)
      if [[ $mask_pw -eq 1 ]]; then
        dsn_masked=$(echo "$dsn" | sed -E 's|(mysql://[^:]+:)[^@]+(@.*)|\1*****\2|')
        echo "- $name: $dsn_masked"
      else
        echo "- $name: $dsn"
      fi
      if [[ "$debug" == 1 ]]; then
        if [[ -n "$pass" ]]; then
          cmd="$MYSQL_EXEC -h $host -P ${port:-3306} -u $user -p***** $db -e \"$sql\" --ssl-verify-server-cert=off"
        else
          cmd="$MYSQL_EXEC -h $host -P ${port:-3306} -u $user $db -e \"$sql\" --ssl-verify-server-cert=off"
        fi
        echo "[DEBUG] Would run: $cmd"
      fi
    done
    echo -e "\nQuery to run:"
    echo "$sql"
    return 0
  fi
  echo "$targets" | while read -r row; do
    name=$(echo "$row" | jq -r '.name')
    dsn=$(echo "$row" | jq -r '.dsn')
    host=$(get_dsn_val "$dsn" host)
    port=$(get_dsn_val "$dsn" port)
    user=$(get_dsn_val "$dsn" user)
    pass=$(get_dsn_val "$dsn" password)
    db=$(get_dsn_val "$dsn" database)
    echo "========= $name ========="
    if [[ "$debug" == 1 ]]; then
      if [[ -n "$pass" ]]; then
        cmd="$MYSQL_EXEC -h $host -P ${port:-3306} -u $user -p***** $db -e \"$sql\" --ssl-verify-server-cert=off"
      else
        cmd="$MYSQL_EXEC -h $host -P ${port:-3306} -u $user $db -e \"$sql\" --ssl-verify-server-cert=off"
      fi
      echo "[DEBUG] Running: $cmd"
    fi
    if [[ -n "$pass" ]]; then
      "$MYSQL_EXEC" -h "$host" -P "${port:-3306}" -u "$user" -p"$pass" "$db" -e "$sql" --ssl-verify-server-cert=off 2>&1 |
        tee -a "$LOG_FILE"
    else
      "$MYSQL_EXEC" -h "$host" -P "${port:-3306}" -u "$user" "$db" -e "$sql" --ssl-verify-server-cert=off 2>&1 |
        tee -a "$LOG_FILE"
    fi
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
      sql=$(yq ".queries[] | select(.name == \"$queryname\") | .query" mysqlman-queries.yaml)
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
