#!/bin/bash

# MySQL CLI Tool: YAML config + DSN + filter + dry-run support
# Dependencies: yq (https://github.com/mikefarah/yq), mysql client

CONFIG_FILE="databases.yaml"
LOG_FILE="logs/execution.log"
mkdir -p logs

usage() {
  cat <<EOF
Usage: $0 <command> [options]

Commands:
  list [--filter key=value]
      List configured databases, optionally filtering by a field.
  query [--query SQL | --query-file FILE | --query-name QUERY_NAME] [--databases names] [--filter key=value] [--dry-run]
      Execute a query on specified databases (by names or filtered). Query can be from the command line, a file, or picked from queries.yaml by name. Use --dry-run to preview.
  help
      Show this help message.

Examples:
  $0 list --filter host=localhost
  $0 query --query "SELECT * FROM users;" --filter host=devhost
  $0 query --query-name get_all_users --databases production
  $0 query --query-file q.sql --databases prod,dev --dry-run
EOF
}

# Extract DSN details under key (field)
get_dsn_val() {
  local dsn="$1"
  local key="$2"
  case "$key" in
    user) echo "$dsn" | sed -nE 's|mysql://([^:]+):.*@.*|\1|p' ;;
    password) echo "$dsn" | sed -nE 's|mysql://[^:]+:([^@]+)@.*|\1|p' ;;
    host) echo "$dsn" | sed -nE 's|mysql://[^:]+:[^@]+@([^:/]+).*|\1|p' ;;
    port) echo "$dsn" | sed -nE 's|mysql://[^:]+:[^@]+@[^:/]+:([0-9]*)/.*|\1|p' ;;
    database) echo "$dsn" | sed -nE 's|mysql://[^:]+:[^@]+@[^:/]+(:[0-9]+)?/([^/?&#]+).*|\2|p' ;;
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
  local dbs
  if [[ -n "$filter" ]]; then
    dbs=$(yq ".databases[] | select(.dsn | contains(\"${filter//=/\":\"}\"))" "$CONFIG_FILE")
  else
    dbs=$(yq '.databases[]' "$CONFIG_FILE")
  fi
  local idx=1
  echo -e "ID | Name        | Host              | Port | Database"
  echo "--------------------------------------------------------------"
  yq -c '.databases[]' "$CONFIG_FILE" | while read -r row; do
    name=$(echo "$row" | jq -r '.name')
    dsn=$(echo "$row" | jq -r '.dsn')
    host=$(get_dsn_val "$dsn" host)
    port=$(get_dsn_val "$dsn" port)
    db=$(get_dsn_val "$dsn" database)
    printf "%2s | %-10s | %-17s | %-4s | %s\n" "$idx" "$name" "$host" "${port:-3306}" "$db"
    idx=$((idx + 1))
  done
}

# Find databases by comma-separated list and/or filter
get_target_dbs() {
  local dbnames="$1"
  local filter="$2"
  if [[ -n "$dbnames" ]]; then
    IFS=',' read -ra names_arr <<< "$dbnames"
    for dbn in "${names_arr[@]}"; do
      yq ".databases[] | select(.name == \"$dbn\")" "$CONFIG_FILE"
    done
  elif [[ -n "$filter" ]]; then
    yq ".databases[] | select(.dsn | contains(\"${filter//=/\":\"}\"))" "$CONFIG_FILE"
  else
    yq '.databases[]' "$CONFIG_FILE"
  fi
}

# Query databases (takes SQL, dbnames, and/or filter, dryrun flag)
query_dbs() {
  local sql="$1"
  local dbnames="$2"
  local filter="$3"
  local dryrun="$4"
  local targets
  targets=$(get_target_dbs "$dbnames" "$filter")
  if [[ -z "$targets" ]]; then
    echo "No matching databases found."
    exit 2
  fi
  if [[ "$dryrun" == 1 ]]; then
    echo "[DRY RUN] Would execute query on the following databases:"
    echo "$targets" | yq -o=json '.' | jq -r '.name' | awk '{print "- "$1}'
    echo -e "\nQuery to run:"; echo "$sql"
    return 0
  fi
  echo "$targets" | yq -o=json '.' | jq -c '.' | while read -r row; do
    name=$(echo "$row" | jq -r '.name')
    dsn=$(echo "$row" | jq -r '.dsn')
    host=$(get_dsn_val "$dsn" host)
    port=$(get_dsn_val "$dsn" port)
    user=$(get_dsn_val "$dsn" user)
    pass=$(get_dsn_val "$dsn" password)
    db=$(get_dsn_val "$dsn" database)
    echo "========= $name ========="
    mysql -h "$host" -P "${port:-3306}" -u "$user" -p"$pass" "$db" -e "$sql" 2>&1 |
      tee -a "$LOG_FILE"
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
    dbnames=""
    filter=""
    dryrun=0
    while [[ "$1" ]]; do
      case "$1" in
        --query) sql="$2"; shift 2;;
        --query-file) sqlfile="$2"; shift 2;;
        --query-name) queryname="$2"; shift 2;;
        --databases) dbnames="$2"; shift 2;;
        --filter) filter="$2"; shift 2;;
        --dry-run) dryrun=1; shift;;
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
      if [[ ! -f "queries.yaml" ]]; then
        echo "Error: queries.yaml not found."; exit 1;
      fi
      sql=$(yq ".queries[] | select(.name == \"$queryname\") | .query" queries.yaml)
      if [[ -z "$sql" || "$sql" == "null" ]]; then
        echo "Error: Query named '$queryname' not found in queries.yaml."; exit 1;
      fi
    fi
    if [[ -z "$sql" ]]; then
      echo "Query required (use --query, --query-file, or --query-name)."; exit 1;
    fi
    query_dbs "$sql" "$dbnames" "$filter" "$dryrun"
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
