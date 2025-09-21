# Makefile for pg_tdlib_parser inside Docker
MODULE_big = pg_tdlib_parser
OBJS = pg_tdlib_parser.o

EXTENSION = pg_tdlib_parser
DATA = pg_tdlib_parser--1.0.sql
PGFILEDESC = "pg_tdlib_parser - Full TDLib integration"

# Link against installed TDLib
SHLIB_LINK = -L/usr/local/lib \
    -ltdcore \
    -ltddb \
    -ltdactor \
    -ltdutils \
    -ltdnet \
    -ltdapi \
    -lssl \
    -lcrypto \
    -lz \
    -ldl \
    -lpthread \
    -lc++ \
    -lc++abi

override PG_CXXFLAGS = -std=c++14 -stdlib=libc++ -fPIC -Wall -I/usr/local/include -I/tdlib -I/tdlib/td -I/tdlib/build -I/tdlib/tdutils
CXX = /usr/bin/clang++
CC = /usr/bin/clang

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

%.o : %.cpp
	/usr/bin/clang++ -std=c++14 -stdlib=libc++ -fPIC -Wall -I/usr/local/include $(CPPFLAGS) -I$(includedir_server) -c -o $@ $<