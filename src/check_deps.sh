check_deps() {
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
    echo -e "\033[31mERROR:\033[0m Neither mariadb nor mysql client is installed or in $PATH." >&2
    echo "Please install mariadb-client or mysql-client and ensure it is in your PATH." >&2
    exit 1
  fi
  # Check for yq dependency
  if command -v yq.exe >/dev/null 2>&1; then
    YQ_EXEC="yq.exe"
  elif command -v yq >/dev/null 2>&1; then
    YQ_EXEC="yq"
  else
    echo -e "\033[31mERROR:\033[0m yq is not installed or in $PATH." >&2
    echo "Please install yq and ensure it is in your PATH." >&2
    exit 1
  fi
}
export MYSQL_EXEC
export YQ_EXEC