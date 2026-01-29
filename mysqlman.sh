#!/bin/bash

# Source all function files from src
for f in "$(dirname "$0")/src"/*.sh; do
  [ -e "$f" ] && source "$f"
done

check_deps

# MySQL/MariaDB CLI Tool: YAML config + DSN + filter + dry-run support
# Dependencies: yq (https://github.com/mikefarah/yq), mariadb or mysql client

CONFIG_FILE="mysqlman-connections.yaml"
LOG_FILE="mysqlman.log"

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
      sql="$(echo "$sql" | sed -E 's/^\s*["'\'']?([^"'\''].*[^"'\'']+)["'\'']?\s*$/\1/' | sed 's/^ *//;s/ *$//')"
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