# PostgreSQL 17 Custom Docker Images

This repository provides PostgreSQL 17 Docker images with various extensions pre-installed.

## Available Image Variants

### 1. PostgreSQL with ULID (`postgres-ulid`)
- **Image**: `ghcr.io/caoer/postgres-custom/postgres-ulid:latest`
- **Extensions**: pgx_ulid
- **Use case**: Applications requiring ULID (Universally Unique Lexicographically Sortable Identifier) support

### 2. PostgreSQL with TimescaleDB (`postgres-timescaledb`)
- **Image**: `ghcr.io/caoer/postgres-custom/postgres-timescaledb:latest`
- **Extensions**: TimescaleDB
- **Use case**: Time-series data applications requiring advanced time-series features

### 3. PostgreSQL with TimescaleDB + ULID (`postgres-full`)
- **Image**: `ghcr.io/caoer/postgres-custom/postgres-full:latest`
- **Extensions**: TimescaleDB, pgx_ulid
- **Use case**: Applications requiring both time-series capabilities and ULID support

## Usage

### Docker Run
```bash
# ULID variant
docker run -d \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -p 5432:5432 \
  ghcr.io/caoer/postgres-custom/postgres-ulid:latest

# TimescaleDB variant
docker run -d \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -p 5432:5432 \
  ghcr.io/caoer/postgres-custom/postgres-timescaledb:latest

# Full variant (TimescaleDB + ULID)
docker run -d \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -p 5432:5432 \
  ghcr.io/caoer/postgres-custom/postgres-full:latest
```

### Docker Compose
```yaml
version: '3.8'

services:
  postgres:
    image: ghcr.io/caoer/postgres-custom/postgres-full:latest
    environment:
      POSTGRES_PASSWORD: mysecretpassword
      POSTGRES_DB: mydb
      POSTGRES_USER: myuser
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

## Extension Details

### pgx_ulid
The pgx_ulid extension provides ULID support for PostgreSQL. ULIDs are:
- 128-bit compatibility with UUID
- 1.21e+24 unique ULIDs per millisecond
- Lexicographically sortable
- Canonically encoded as a 26 character string

Example usage:
```sql
CREATE EXTENSION pgx_ulid;
SELECT ulid_generate();
```

### TimescaleDB
TimescaleDB is an open-source time-series database built on PostgreSQL, providing:
- Automatic partitioning across time and space
- Advanced time-series functions
- Real-time aggregations
- Data retention policies

Example usage:
```sql
CREATE EXTENSION timescaledb;
CREATE TABLE metrics (
  time TIMESTAMPTZ NOT NULL,
  device_id TEXT,
  value DOUBLE PRECISION
);
SELECT create_hypertable('metrics', 'time');
```

## Build Information

All images are:
- Based on official PostgreSQL 17 (bookworm)
- Multi-platform support (linux/amd64, linux/arm64)
- Automatically built and pushed to GitHub Container Registry
- Health check enabled

## License

See the main repository LICENSE file.