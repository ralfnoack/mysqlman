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
