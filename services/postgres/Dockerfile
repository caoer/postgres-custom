# Build stage for pgx_ulid extension
FROM postgres:17-bookworm AS builder

# Install build dependencies and PostgreSQL dev headers
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    pkg-config \
    libssl-dev \
    clang \
    postgresql-server-dev-17 \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Clone pgx_ulid extension
WORKDIR /tmp
RUN git clone https://github.com/pksunkara/pgx_ulid.git
WORKDIR /tmp/pgx_ulid

# Install cargo-pgrx (matching version with pgx_ulid requirements)
RUN cargo install cargo-pgrx --version "0.16.0" --locked
RUN cargo pgrx init --pg17 $(which pg_config)

# Build the extension for PostgreSQL 17
RUN cargo pgrx package --pg-config $(which pg_config)

# Final stage - PostgreSQL 17 with ulid extension
FROM postgres:17-bookworm

# Copy the built extension files from the builder stage
COPY --from=builder /tmp/pgx_ulid/target/release/pgx_ulid-pg17/usr/share/postgresql/17/extension/* /usr/share/postgresql/17/extension/
COPY --from=builder /tmp/pgx_ulid/target/release/pgx_ulid-pg17/usr/lib/postgresql/17/lib/* /usr/lib/postgresql/17/lib/

# Create initialization script to install the extension
RUN echo "CREATE EXTENSION IF NOT EXISTS pgx_ulid;" > /docker-entrypoint-initdb.d/01-ulid.sql

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
  CMD pg_isready -U postgres || exit 1