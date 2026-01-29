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
