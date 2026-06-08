aws_region     = "us-east-1"
environment    = "dev"
project_name   = "SimpleCrud"
table_name     = "CrudTable"
user_pool_name = "SimpleCrudUserPool"

# RDS / PostgreSQL — update these with your RDS instance details
db_host     = "database-1-instance-1.cejcsyiy8cpy.us-east-1.rds.amazonaws.com"
#db_host     = "your-rds-endpoint.us-east-1.rds.amazonaws.com"
db_port     = "5432"
db_name     = "postgres"
db_user     = "postgres"
db_password = "database-1-instance-1.cejcsyiy8cpy.us-east-1.rds.amazonaws.com:5432/?Action=connect&DBUser=postgres&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ASIASAXZQZXYCPCYCYH6%2F20260608%2Fus-east-1%2Frds-db%2Faws4_request&X-Amz-Date=20260608T163607Z&X-Amz-Expires=900&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEPH%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJHMEUCIQDPQzAR%2BTOk13km4VfpEAk%2FW8Zps8NoAxs%2F8dOic15NEgIgREgNM2dpgrZcF452Ax7WShTVWMj4ZvhkLtTYMGGsJm0q5gIIuv%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARAAGgwxMzkwMzU5ODc0NDAiDNe0wFkqAlJUjXrXfiq6AitnZhZmbDQTV4JznYGd%2F74dV1IaJwdZo3wYURs9VgqYpollQE%2FXCbTpQAWi36chHkcQuz90jPSu1v7BtJy55V5VQdnFNHbt9D3augN9jYQysId%2FvBCyZL%2B6JVBPkqmkAvrHb5AGTFVEO7QOOXgu%2FHUhztbOvA%2FWGmnRn6spu%2BRFtrOlOrBU5T9SsduPADZTNELO04j0SpJCO4r6z0lbKbZeZiUsYFhjRePrfQ3TUUBT1vMfu8MGIVhyDsWWJWa6VsU%2FIHNEvEdSJwkiNcTLVCT9m6UB09fh88kdtKmbDLIs6G2hT6vrC3uHmW7ZyQEwY5N8Aq1pzvYgUbAN74CZwYP%2BT9KhEwteW%2FqVqyAWQcigQdUbwM2SrqfCaCFcP8N%2Fl%2FQYZlSqiyWl5TMit9Dn0%2BfDbeek7Zwk6vTcMMipmdEGOq0CcsU66erfYZfJHtKcZQ%2FSa9iNw0Eb477QOA5KhD29tlAL9YAPKUbBbGtxVbtjuHzw%2BE71d54bmA%2B%2FOtRK70L5WScAHVZwtmFoFmP2ZTCT%2FF2p%2BV64UURZBMyW5uqMfXQwvFbomIvrNVvky4apTZMBkaZK6JTdUYu7jgT88Tc1n4E1xvXjVI5z5RP7zW1D3rJ%2FgY4nSeYGV3CUBpCIGm9H5Pl7vEMZrwXFJ9MzDFM%2FLqAzADLsVTv4qix5rhMdaTMqJ7QuNQnjqQPOsJvOzC47glZA445IYuP0963dj2n7fyGxYbEB0dQIKMvhHCWOdszIJ%2BE%2FfzQ65CEsEGOSy5FcFLJsFl3ouLzeSq9YQ1k6qCTetEvp6UnZ8XdSYW6GcQ0zrRV%2BiXdzN3I67Avm9A%3D%3D&X-Amz-Signature=a118bdaeb301925799a439abffb8688f4b01a0428c56a10d1cda81dc9769f851&X-Amz-SignedHeaders=host"

common_tags = {
  Owner = "DevTeam"
}
