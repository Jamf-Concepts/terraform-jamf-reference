# Remote state in PostgreSQL. The block is empty on purpose. Terraform reads
# the connection string from PG_CONN_STR and the schema from PG_SCHEMA_NAME,
# so no backend value lives in the repository. Each environment gets its own
# schema, and so its own state.

terraform {
  backend "pg" {}
}
