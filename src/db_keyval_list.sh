db_keyval_list() {
  "$YQ_EXEC" '.databases' -op "$CONFIG_FILE"
}
