-- pg_tdlib_parser extension SQL definitions
-- Full TDLib integration for parsing MTProto/Telegram binary data

-- Parse telegram_api binary data to JSONB
CREATE OR REPLACE FUNCTION tdlib_parse_telegram_api(data bytea)
RETURNS jsonb
AS 'MODULE_PATHNAME', 'tdlib_parse_telegram_api'
LANGUAGE C IMMUTABLE STRICT;

COMMENT ON FUNCTION tdlib_parse_telegram_api(bytea) IS
'Parse telegram_api binary data to JSONB. Supports ALL telegram_api types including automatic gzip decompression.';

-- Parse td_api binary data to JSONB
CREATE OR REPLACE FUNCTION tdlib_parse_td_api(data bytea)
RETURNS jsonb
AS 'MODULE_PATHNAME', 'tdlib_parse_td_api'
LANGUAGE C IMMUTABLE STRICT;

COMMENT ON FUNCTION tdlib_parse_td_api(bytea) IS
'Parse td_api binary data to JSONB. Supports ALL td_api types.';

-- Parse mtproto_api binary data to JSONB
CREATE OR REPLACE FUNCTION tdlib_parse_mtproto_api(data bytea)
RETURNS jsonb
AS 'MODULE_PATHNAME', 'tdlib_parse_mtproto_api'
LANGUAGE C IMMUTABLE STRICT;

COMMENT ON FUNCTION tdlib_parse_mtproto_api(bytea) IS
'Parse mtproto_api binary data to JSONB. Supports ALL mtproto_api types.';

-- Auto-detect schema and parse binary data
CREATE OR REPLACE FUNCTION tdlib_parse_auto(data bytea)
RETURNS jsonb
AS 'MODULE_PATHNAME', 'tdlib_parse_auto'
LANGUAGE C IMMUTABLE STRICT;

COMMENT ON FUNCTION tdlib_parse_auto(bytea) IS
'Auto-detect schema (telegram_api, td_api, or mtproto_api) and parse binary data to JSONB.';

-- Parse hex-encoded data with auto-detection
CREATE OR REPLACE FUNCTION tdlib_parse_hex(hex_data text)
RETURNS jsonb
AS 'MODULE_PATHNAME', 'tdlib_parse_hex'
LANGUAGE C IMMUTABLE STRICT;

COMMENT ON FUNCTION tdlib_parse_hex(text) IS
'Parse hex-encoded MTProto/Telegram data with automatic schema detection.';

-- Parse hex-encoded data with specified schema
CREATE OR REPLACE FUNCTION tdlib_parse_hex_with_schema(hex_data text, schema text)
RETURNS jsonb
AS 'MODULE_PATHNAME', 'tdlib_parse_hex_with_schema'
LANGUAGE C IMMUTABLE STRICT;

COMMENT ON FUNCTION tdlib_parse_hex_with_schema(text, text) IS
'Parse hex-encoded data with specified schema (telegram_api, td_api, mtproto_api, or auto).';

-- Identify constructor from binary data
CREATE OR REPLACE FUNCTION tdlib_identify_constructor(data bytea)
RETURNS text
AS 'MODULE_PATHNAME', 'tdlib_identify_constructor'
LANGUAGE C IMMUTABLE STRICT;

COMMENT ON FUNCTION tdlib_identify_constructor(bytea) IS
'Identify the constructor type from binary data.';

-- List common telegram_api constructors
CREATE OR REPLACE FUNCTION tdlib_list_telegram_constructors()
RETURNS text
AS 'MODULE_PATHNAME', 'tdlib_list_telegram_constructors'
LANGUAGE C IMMUTABLE;

COMMENT ON FUNCTION tdlib_list_telegram_constructors() IS
'List common telegram_api constructor IDs and their types.';

-- Get version and feature information
CREATE OR REPLACE FUNCTION tdlib_version()
RETURNS jsonb
AS 'MODULE_PATHNAME', 'tdlib_version'
LANGUAGE C IMMUTABLE;

COMMENT ON FUNCTION tdlib_version() IS
'Get pg_tdlib_parser version and feature information.';

-- Convenience view for version info
CREATE OR REPLACE VIEW pg_tdlib_parser_info AS
SELECT tdlib_version() AS info;

COMMENT ON VIEW pg_tdlib_parser_info IS
'View showing pg_tdlib_parser version and capabilities.';

-- Helper function with timing for performance testing
CREATE OR REPLACE FUNCTION tdlib_parse_hex_timed(hex_data text)
RETURNS TABLE(result jsonb, parse_time_ms numeric)
AS $$
DECLARE
    start_time timestamp;
    end_time timestamp;
BEGIN
    start_time := clock_timestamp();
    result := tdlib_parse_hex(hex_data);
    end_time := clock_timestamp();
    parse_time_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION tdlib_parse_hex_timed(text) IS
'Parse hex-encoded data and return result with parsing time in milliseconds.';

-- Example usage message
DO $$
BEGIN
    RAISE NOTICE 'pg_tdlib_parser extension installed successfully!';
    RAISE NOTICE '';
    RAISE NOTICE 'Example usage:';
    RAISE NOTICE '  SELECT tdlib_parse_hex(''632416050123456789...'');';
    RAISE NOTICE '  SELECT tdlib_parse_hex_with_schema(''632416050123456789...'', ''telegram_api'');';
    RAISE NOTICE '  SELECT tdlib_identify_constructor(decode(''63241605'', ''hex''));';
    RAISE NOTICE '  SELECT * FROM pg_tdlib_parser_info;';
    RAISE NOTICE '';
    RAISE NOTICE 'This extension supports ALL TDLib types from:';
    RAISE NOTICE '  - telegram_api (internal Telegram/MTProto protocol)';
    RAISE NOTICE '  - td_api (public TDLib API)';
    RAISE NOTICE '  - mtproto_api (MTProto transport layer)';
END;
$$;