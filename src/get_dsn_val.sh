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
