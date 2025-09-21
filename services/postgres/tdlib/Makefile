# Makefile for pg_tdlib_parser PostgreSQL extension
MODULE_big = pg_tdlib_parser
OBJS = pg_tdlib_parser.o

EXTENSION = pg_tdlib_parser
DATA = pg_tdlib_parser--1.0.sql
PGFILEDESC = "pg_tdlib_parser - Full TDLib integration for parsing MTProto/Telegram data"

TDLIB_INCLUDE_PATH = /usr/local/include
TDLIB_LIB_PATH = /usr/local/lib

# Required TDLib libraries
SHLIB_LINK = -L$(TDLIB_LIB_PATH) \
    -ltdapi \
    -ltdclient \
    -ltdcore \
    -ltddb \
    -ltdactor \
    -ltdutils \
    -ltdnet \
    -ltdsqlite \
    -lssl \
    -lcrypto \
    -lz \
    -ldl \
    -lpthread \
    -lstdc++

# C++ compilation flags
override PG_CXXFLAGS = -std=c++14 -fPIC -Wall -Wextra \
    -I$(TDLIB_INCLUDE_PATH) \
    -I/tdlib \
    -I/tdlib/td \
    -I/tdlib/build \
    -DHAVE_CONFIG_H

# PostgreSQL configuration
PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# Override to use C++ compiler
%.o : %.cpp
	$(CXX) $(PG_CXXFLAGS) $(CPPFLAGS) -I$(includedir_server) -c -o $@ $<

# Clean rule
clean:
	rm -f $(OBJS) $(MODULE_big).so

# Install rule handled by PGXS

.PHONY: clean