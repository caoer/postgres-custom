#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
until pg_isready -U postgres; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 1
done

# Create extension
psql -U postgres -d postgres <<EOF
CREATE EXTENSION IF NOT EXISTS pg_tdlib_parser;
\dx pg_tdlib_parser
SELECT * FROM pg_tdlib_parser_info;
EOF

echo "pg_tdlib_parser extension installed successfully!"