# mysqlman.sh: Multi-DB MySQL/MariaDB Bash CLI

This tool provides a robust command-line interface for running SQL queries across multiple MySQL or MariaDB databases, with configuration in YAML and secure handling of credentials.

## Features

- Manage database configs and credentials in `mysqlman-connections.yaml` (single or multiple).
- Run queries directly or from a reusable mysqlman-queries.yaml file (`--query-name`).
- Use advanced filtering for database selection (`--filter key=value`).
- **Dry-run** to preview targets and queries, with masked credentials.
- Supports both `mysql` and `mariadb` executables (uses `mariadb` if available).
- Output fields: Name, User, Host, Port, Database.
- Robust DSN parsing (password, no-password, missing fields).
- **Debug mode** with real CLI command print (masked passwords).

## Requirements

- bash
- `yq` (YAML processor, v3 syntax)
- `jq` (for JSON field extraction)
- MySQL or MariaDB client (`mysql` or `mariadb` command)

## Installation

- Place `mysqlman.sh` in your project/root folder and make it executable:
  ```bash
  chmod +x mysqlman.sh
  ```
- Prepare a `mysqlman-connections.yaml` and (optionally) `mysqlman-queries.yaml` in the same directory.

## Usage

Show help:
```bash
./mysqlman.sh help
```

### List databases

```bash
./mysqlman.sh list
```
Sample output:
```
ID  | Name          | User      | Host        | Port | Database
---------------------------------------------------------------
1   | dev           | root      | localhost   | 3306 | mydb
```

### Query example

Raw query:
```bash
./mysqlman.sh query --db dev --query 'SELECT NOW();'
```

Predefined query (with `mysqlman-queries.yaml`):
```yaml
queries:
  - name: default
    query: "SHOW DATABASES;"
    description: "List all databases."
```
Run:
```bash
./mysqlman.sh query --query-name default --filter name=dev
```

Dry-run:
```bash
./mysqlman.sh query --db dev --query 'SELECT 1;' --dry-run
```

Debug:
```bash
./mysqlman.sh query --db dev --query 'SELECT 1;' --debug
```

Filtering:
```bash
./mysqlman.sh list --filter host=localhost
./mysqlman.sh query --filter name=dev --query 'SHOW TABLES;'
```

### DSN Config Example (`mysqlman-connections.yaml`)

```yaml
databases:
  - name: dev
    dsn: mysql://root@localhost:3306/dev_db
  - name: prod
    dsn: mysql://admin:securepw@prodhost:3306/prod_db
```

## Development

- Lint:
  ```bash
  shellcheck mysqlman.sh
  ```
- (Optionally) Format:
  ```bash
  shfmt -w mysqlman.sh
  ```
- Add new databases by editing `mysqlman-connections.yaml`; add pre-defined queries to `mysqlman-queries.yaml` (see above).

## Troubleshooting

- **SSL errors with self-signed certs:**  
  By default, the CLI disables server cert verification when running queries.
- **Password-less users:**  
  If no password is specified in the DSN, the CLI omits `-p` (no interactive prompt).

## Contributing

See AGENTS.md for agent/coding automation guidelines!

## License

SPDX: MIT
