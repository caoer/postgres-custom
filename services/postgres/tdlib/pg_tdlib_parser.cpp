/*
 * pg_tdlib_parser.cpp - PostgreSQL extension for parsing MTProto/Telegram binary data
 * Full TDLib integration with support for ALL telegram_api and td_api types
 */

 extern "C" {
    #include "postgres.h"
    #include "fmgr.h"
    #include "utils/builtins.h"
    #include "utils/jsonb.h"
    #include "utils/json.h"
    #include "catalog/pg_type.h"
    #include "libpq/pqformat.h"
    #include "funcapi.h"
    #include "utils/timestamp.h"
    #include "utils/lsyscache.h"
    
    #ifdef PG_MODULE_MAGIC
    PG_MODULE_MAGIC;
    #endif
    }
    
    // Standard C++ includes
    #include <memory>
    #include <string>
    #include <sstream>
    #include <vector>
    #include <unordered_map>
    #include <iomanip>
    
    // Undefine PostgreSQL macros that conflict with TDLib
    #ifdef LOG
    #undef LOG
    #endif
    #ifdef foreach
    #undef foreach
    #endif
    #ifdef likely
    #undef likely
    #endif
    #ifdef unlikely
    #undef unlikely
    #endif
    
    // TDLib expects std types to be available
    using namespace std;
    
    // TDLib core includes
    #include "td/utils/buffer.h"
    #include "td/utils/tl_parsers.h"
    #include "td/utils/JsonBuilder.h"
    #include "td/utils/base64.h"
    #include "td/utils/Slice.h"
    #include "td/utils/StringBuilder.h"
    #include "td/utils/logging.h"
    #include "td/utils/format.h"
    #include "td/utils/misc.h"
    #include "td/utils/Status.h"
    
    // TL JSON conversion
    #include "td/tl/tl_json.h"
    
    // Generated TL API headers - these contain ALL the types
    #include "td/telegram/telegram_api.h"
    #include "td/telegram/td_api.h"
    #include "td/mtproto/mtproto_api.h"
    #include "td/telegram/secret_api.h"
    
    // For gzip decompression
    #include <zlib.h>
    
    extern "C" {
    
    /* Function declarations */
    Datum tdlib_parse_telegram_api(PG_FUNCTION_ARGS);
    Datum tdlib_parse_td_api(PG_FUNCTION_ARGS);
    Datum tdlib_parse_mtproto_api(PG_FUNCTION_ARGS);
    Datum tdlib_parse_hex(PG_FUNCTION_ARGS);
    Datum tdlib_parse_hex_with_schema(PG_FUNCTION_ARGS);
    Datum tdlib_identify_constructor(PG_FUNCTION_ARGS);
    Datum tdlib_parse_auto(PG_FUNCTION_ARGS);
    Datum tdlib_list_telegram_constructors(PG_FUNCTION_ARGS);
    Datum tdlib_version(PG_FUNCTION_ARGS);
    
    PG_FUNCTION_INFO_V1(tdlib_parse_telegram_api);
    PG_FUNCTION_INFO_V1(tdlib_parse_td_api);
    PG_FUNCTION_INFO_V1(tdlib_parse_mtproto_api);
    PG_FUNCTION_INFO_V1(tdlib_parse_hex);
    PG_FUNCTION_INFO_V1(tdlib_parse_hex_with_schema);
    PG_FUNCTION_INFO_V1(tdlib_identify_constructor);
    PG_FUNCTION_INFO_V1(tdlib_parse_auto);
    PG_FUNCTION_INFO_V1(tdlib_list_telegram_constructors);
    PG_FUNCTION_INFO_V1(tdlib_version);
    
    /*
     * Decompress gzip data
     */
    static std::string decompress_gzip(const unsigned char *data, size_t size) {
        z_stream stream = {};
        stream.next_in = const_cast<unsigned char*>(data);
        stream.avail_in = size;
    
        if (inflateInit2(&stream, 16 + MAX_WBITS) != Z_OK) {
            return "";
        }
    
        std::string result;
        char buffer[4096];
    
        do {
            stream.next_out = reinterpret_cast<unsigned char*>(buffer);
            stream.avail_out = sizeof(buffer);
    
            int ret = inflate(&stream, Z_NO_FLUSH);
            if (ret != Z_OK && ret != Z_STREAM_END) {
                inflateEnd(&stream);
                return "";
            }
    
            result.append(buffer, sizeof(buffer) - stream.avail_out);
    
            if (ret == Z_STREAM_END) {
                break;
            }
        } while (stream.avail_out == 0);
    
        inflateEnd(&stream);
        return result;
    }
    
    /*
     * Core parsing function that handles any telegram_api object
     */
    static std::string parse_telegram_api_to_json(const unsigned char *data, size_t size, bool auto_decompress = true) {
        try {
            td::TlBufferParser parser(td::Slice(reinterpret_cast<const char*>(data), size));
    
            // Try to parse as telegram_api object
            auto object = td::telegram_api::Object::fetch(parser);
    
            if (parser.get_error()) {
                // If parsing failed, check if it might be gzip_packed
                if (size >= 4 && auto_decompress) {
                    td::int32 constructor_id = *reinterpret_cast<const td::int32*>(data);
                    if (constructor_id == 0x3072cfa1) { // gzip_packed
                        // Skip constructor id and parse string with gzipped data
                        td::TlBufferParser gzip_parser(td::Slice(reinterpret_cast<const char*>(data + 4), size - 4));
                        auto gzipped = gzip_parser.fetch_string<std::string>();
    
                        if (!gzip_parser.get_error() && !gzipped.empty()) {
                            // Decompress and recursively parse
                            auto decompressed = decompress_gzip(
                                reinterpret_cast<const unsigned char*>(gzipped.data()),
                                gzipped.size()
                            );
    
                            if (!decompressed.empty()) {
                                return parse_telegram_api_to_json(
                                    reinterpret_cast<const unsigned char*>(decompressed.data()),
                                    decompressed.size(),
                                    false // Don't recurse on decompression
                                );
                            }
                        }
                    }
                }
    
                // Return error with hex dump of data
                td::JsonBuilder json;
                auto obj = json.enter_object();
                obj("@type", "parse_error");
                obj("error", parser.get_error());
                obj("error_pos", static_cast<td::int64>(parser.get_error_pos()));
                obj("data_size", static_cast<td::int64>(size));
                if (size > 0) {
                    size_t preview_len = std::min(size, size_t(64));
                    obj("data_preview", td::base64_encode(td::Slice(reinterpret_cast<const char*>(data), preview_len)));
                }
                return json.string_builder().as_cslice().str();
            }
    
            // Convert to JSON using TDLib's built-in JSON converter
            td::JsonBuilder json;
            td::to_json(json, object);
            return json.string_builder().as_cslice().str();
    
        } catch (const std::exception &e) {
            td::JsonBuilder json;
            auto obj = json.enter_object();
            obj("@type", "exception");
            obj("message", e.what());
            return json.string_builder().as_cslice().str();
        }
    }
    
    /*
     * Parse td_api objects
     */
    static std::string parse_td_api_to_json(const unsigned char *data, size_t size) {
        try {
            td::TlBufferParser parser(td::Slice(reinterpret_cast<const char*>(data), size));
    
            // Try to parse as td_api object
            auto object = td::td_api::Object::fetch(parser);
    
            if (parser.get_error()) {
                td::JsonBuilder json;
                auto obj = json.enter_object();
                obj("@type", "parse_error");
                obj("error", parser.get_error());
                obj("error_pos", static_cast<td::int64>(parser.get_error_pos()));
                return json.string_builder().as_cslice().str();
            }
    
            // Convert to JSON
            td::JsonBuilder json;
            td::to_json(json, object);
            return json.string_builder().as_cslice().str();
    
        } catch (const std::exception &e) {
            td::JsonBuilder json;
            auto obj = json.enter_object();
            obj("@type", "exception");
            obj("message", e.what());
            return json.string_builder().as_cslice().str();
        }
    }
    
    /*
     * Parse mtproto_api objects
     */
    static std::string parse_mtproto_api_to_json(const unsigned char *data, size_t size) {
        try {
            td::TlBufferParser parser(td::Slice(reinterpret_cast<const char*>(data), size));
    
            // Try to parse as mtproto_api object
            auto object = td::mtproto_api::Object::fetch(parser);
    
            if (parser.get_error()) {
                td::JsonBuilder json;
                auto obj = json.enter_object();
                obj("@type", "parse_error");
                obj("error", parser.get_error());
                obj("error_pos", static_cast<td::int64>(parser.get_error_pos()));
                return json.string_builder().as_cslice().str();
            }
    
            // Convert to JSON
            td::JsonBuilder json;
            td::to_json(json, object);
            return json.string_builder().as_cslice().str();
    
        } catch (const std::exception &e) {
            td::JsonBuilder json;
            auto obj = json.enter_object();
            obj("@type", "exception");
            obj("message", e.what());
            return json.string_builder().as_cslice().str();
        }
    }
    
    /*
     * Auto-detect schema and parse
     */
    static std::string parse_auto_to_json(const unsigned char *data, size_t size) {
        // Try each schema in order of likelihood
    
        // 1. Try telegram_api (most common)
        {
            td::TlBufferParser parser(td::Slice(reinterpret_cast<const char*>(data), size));
            auto object = td::telegram_api::Object::fetch(parser);
            if (!parser.get_error()) {
                td::JsonBuilder json;
                auto wrapper = json.enter_object();
                wrapper("@schema", "telegram_api");
                wrapper("data", [&](auto &jv) {
                    td::to_json(jv, object);
                });
                return json.string_builder().as_cslice().str();
            }
        }
    
        // 2. Try td_api
        {
            td::TlBufferParser parser(td::Slice(reinterpret_cast<const char*>(data), size));
            auto object = td::td_api::Object::fetch(parser);
            if (!parser.get_error()) {
                td::JsonBuilder json;
                auto wrapper = json.enter_object();
                wrapper("@schema", "td_api");
                wrapper("data", [&](auto &jv) {
                    td::to_json(jv, object);
                });
                return json.string_builder().as_cslice().str();
            }
        }
    
        // 3. Try mtproto_api
        {
            td::TlBufferParser parser(td::Slice(reinterpret_cast<const char*>(data), size));
            auto object = td::mtproto_api::Object::fetch(parser);
            if (!parser.get_error()) {
                td::JsonBuilder json;
                auto wrapper = json.enter_object();
                wrapper("@schema", "mtproto_api");
                wrapper("data", [&](auto &jv) {
                    td::to_json(jv, object);
                });
                return json.string_builder().as_cslice().str();
            }
        }
    
        // If all fail, return error with constructor ID
        td::JsonBuilder json;
        auto obj = json.enter_object();
        obj("@type", "unknown_schema");
        if (size >= 4) {
            td::int32 constructor_id = *reinterpret_cast<const td::int32*>(data);
            obj("constructor_id", td::format::as_hex(constructor_id));
        }
        obj("data_size", static_cast<td::int64>(size));
        if (size > 0) {
            size_t preview_len = std::min(size, size_t(32));
            obj("data_preview", td::base64_encode(td::Slice(reinterpret_cast<const char*>(data), preview_len)));
        }
        return json.string_builder().as_cslice().str();
    }
    
    /*
     * tdlib_parse_telegram_api - Parse telegram_api binary to JSON
     */
    Datum
    tdlib_parse_telegram_api(PG_FUNCTION_ARGS)
    {
        bytea *input = PG_GETARG_BYTEA_PP(0);
        unsigned char *data = (unsigned char *)VARDATA_ANY(input);
        size_t size = VARSIZE_ANY_EXHDR(input);
    
        std::string json = parse_telegram_api_to_json(data, size);
    
        // Convert to PostgreSQL JSONB
        Datum json_datum = CStringGetDatum(json.c_str());
        PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in, json_datum));
    }
    
    /*
     * tdlib_parse_td_api - Parse td_api binary to JSON
     */
    Datum
    tdlib_parse_td_api(PG_FUNCTION_ARGS)
    {
        bytea *input = PG_GETARG_BYTEA_PP(0);
        unsigned char *data = (unsigned char *)VARDATA_ANY(input);
        size_t size = VARSIZE_ANY_EXHDR(input);
    
        std::string json = parse_td_api_to_json(data, size);
    
        // Convert to PostgreSQL JSONB
        Datum json_datum = CStringGetDatum(json.c_str());
        PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in, json_datum));
    }
    
    /*
     * tdlib_parse_mtproto_api - Parse mtproto_api binary to JSON
     */
    Datum
    tdlib_parse_mtproto_api(PG_FUNCTION_ARGS)
    {
        bytea *input = PG_GETARG_BYTEA_PP(0);
        unsigned char *data = (unsigned char *)VARDATA_ANY(input);
        size_t size = VARSIZE_ANY_EXHDR(input);
    
        std::string json = parse_mtproto_api_to_json(data, size);
    
        // Convert to PostgreSQL JSONB
        Datum json_datum = CStringGetDatum(json.c_str());
        PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in, json_datum));
    }
    
    /*
     * tdlib_parse_auto - Auto-detect schema and parse
     */
    Datum
    tdlib_parse_auto(PG_FUNCTION_ARGS)
    {
        bytea *input = PG_GETARG_BYTEA_PP(0);
        unsigned char *data = (unsigned char *)VARDATA_ANY(input);
        size_t size = VARSIZE_ANY_EXHDR(input);
    
        std::string json = parse_auto_to_json(data, size);
    
        // Convert to PostgreSQL JSONB
        Datum json_datum = CStringGetDatum(json.c_str());
        PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in, json_datum));
    }
    
    /*
     * tdlib_parse_hex - Parse hex string as telegram_api (default)
     */
    Datum
    tdlib_parse_hex(PG_FUNCTION_ARGS)
    {
        text *hex_input = PG_GETARG_TEXT_PP(0);
        char *hex_str = text_to_cstring(hex_input);
        size_t hex_len = strlen(hex_str);
    
        // Validate hex string
        if (hex_len % 2 != 0) {
            ereport(ERROR,
                    (errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
                     errmsg("Hex string must have even length")));
        }
    
        // Convert hex to binary
        size_t binary_size = hex_len / 2;
        std::unique_ptr<unsigned char[]> binary_data(new unsigned char[binary_size]);
    
        for (size_t i = 0; i < binary_size; i++) {
            unsigned int byte;
            if (sscanf(hex_str + i * 2, "%2x", &byte) != 1) {
                ereport(ERROR,
                        (errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
                         errmsg("Invalid hex string at position %zu", i * 2)));
            }
            binary_data[i] = static_cast<unsigned char>(byte);
        }
    
        // Auto-detect and parse
        std::string json = parse_auto_to_json(binary_data.get(), binary_size);
    
        // Convert to PostgreSQL JSONB
        Datum json_datum = CStringGetDatum(json.c_str());
        PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in, json_datum));
    }
    
    /*
     * tdlib_parse_hex_with_schema - Parse hex with specified schema
     */
    Datum
    tdlib_parse_hex_with_schema(PG_FUNCTION_ARGS)
    {
        text *hex_input = PG_GETARG_TEXT_PP(0);
        text *schema_input = PG_GETARG_TEXT_PP(1);
    
        char *hex_str = text_to_cstring(hex_input);
        char *schema_str = text_to_cstring(schema_input);
        size_t hex_len = strlen(hex_str);
    
        // Validate hex string
        if (hex_len % 2 != 0) {
            ereport(ERROR,
                    (errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
                     errmsg("Hex string must have even length")));
        }
    
        // Convert hex to binary
        size_t binary_size = hex_len / 2;
        std::unique_ptr<unsigned char[]> binary_data(new unsigned char[binary_size]);
    
        for (size_t i = 0; i < binary_size; i++) {
            unsigned int byte;
            if (sscanf(hex_str + i * 2, "%2x", &byte) != 1) {
                ereport(ERROR,
                        (errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
                         errmsg("Invalid hex string at position %zu", i * 2)));
            }
            binary_data[i] = static_cast<unsigned char>(byte);
        }
    
        // Parse based on schema
        std::string json;
        if (strcmp(schema_str, "telegram_api") == 0) {
            json = parse_telegram_api_to_json(binary_data.get(), binary_size);
        } else if (strcmp(schema_str, "td_api") == 0) {
            json = parse_td_api_to_json(binary_data.get(), binary_size);
        } else if (strcmp(schema_str, "mtproto_api") == 0) {
            json = parse_mtproto_api_to_json(binary_data.get(), binary_size);
        } else if (strcmp(schema_str, "auto") == 0) {
            json = parse_auto_to_json(binary_data.get(), binary_size);
        } else {
            ereport(ERROR,
                    (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
                     errmsg("Invalid schema: %s. Must be one of: telegram_api, td_api, mtproto_api, auto", schema_str)));
        }
    
        // Convert to PostgreSQL JSONB
        Datum json_datum = CStringGetDatum(json.c_str());
        PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in, json_datum));
    }
    
    /*
     * tdlib_identify_constructor - Identify constructor from binary data
     */
    Datum
    tdlib_identify_constructor(PG_FUNCTION_ARGS)
    {
        bytea *input = PG_GETARG_BYTEA_PP(0);
        unsigned char *data = (unsigned char *)VARDATA_ANY(input);
        size_t size = VARSIZE_ANY_EXHDR(input);
    
        if (size < 4) {
            PG_RETURN_TEXT_P(cstring_to_text("Data too short (< 4 bytes)"));
        }
    
        td::int32 constructor_id = *reinterpret_cast<td::int32*>(data);
    
        // Try to identify the constructor in each schema
        std::string result;
    
        // Check telegram_api
        {
            td::TlBufferParser parser(td::Slice(reinterpret_cast<const char*>(data), size));
            auto object = td::telegram_api::Object::fetch(parser);
            if (!parser.get_error()) {
                // Get the type name from the object
                td::JsonBuilder json;
                td::to_json(json, object);
                auto json_str = json.string_builder().as_cslice().str();
    
                // Parse JSON to get @type
                size_t type_pos = json_str.find("\"@type\":\"");
                if (type_pos != std::string::npos) {
                    type_pos += 9;
                    size_t end_pos = json_str.find("\"", type_pos);
                    if (end_pos != std::string::npos) {
                        std::string type_name = json_str.substr(type_pos, end_pos - type_pos);
                        char buf[256];
                        snprintf(buf, sizeof(buf), "telegram_api::%s (0x%08x)", type_name.c_str(), constructor_id);
                        PG_RETURN_TEXT_P(cstring_to_text(buf));
                    }
                }
            }
        }
    
        // Check td_api
        {
            td::TlBufferParser parser(td::Slice(reinterpret_cast<const char*>(data), size));
            auto object = td::td_api::Object::fetch(parser);
            if (!parser.get_error()) {
                td::JsonBuilder json;
                td::to_json(json, object);
                auto json_str = json.string_builder().as_cslice().str();
    
                size_t type_pos = json_str.find("\"@type\":\"");
                if (type_pos != std::string::npos) {
                    type_pos += 9;
                    size_t end_pos = json_str.find("\"", type_pos);
                    if (end_pos != std::string::npos) {
                        std::string type_name = json_str.substr(type_pos, end_pos - type_pos);
                        char buf[256];
                        snprintf(buf, sizeof(buf), "td_api::%s (0x%08x)", type_name.c_str(), constructor_id);
                        PG_RETURN_TEXT_P(cstring_to_text(buf));
                    }
                }
            }
        }
    
        // Check mtproto_api
        {
            td::TlBufferParser parser(td::Slice(reinterpret_cast<const char*>(data), size));
            auto object = td::mtproto_api::Object::fetch(parser);
            if (!parser.get_error()) {
                td::JsonBuilder json;
                td::to_json(json, object);
                auto json_str = json.string_builder().as_cslice().str();
    
                size_t type_pos = json_str.find("\"@type\":\"");
                if (type_pos != std::string::npos) {
                    type_pos += 9;
                    size_t end_pos = json_str.find("\"", type_pos);
                    if (end_pos != std::string::npos) {
                        std::string type_name = json_str.substr(type_pos, end_pos - type_pos);
                        char buf[256];
                        snprintf(buf, sizeof(buf), "mtproto_api::%s (0x%08x)", type_name.c_str(), constructor_id);
                        PG_RETURN_TEXT_P(cstring_to_text(buf));
                    }
                }
            }
        }
    
        // Unknown constructor
        char buf[256];
        snprintf(buf, sizeof(buf), "unknown (0x%08x)", constructor_id);
        PG_RETURN_TEXT_P(cstring_to_text(buf));
    }
    
    /*
     * tdlib_list_telegram_constructors - List some common telegram_api constructors
     */
    Datum
    tdlib_list_telegram_constructors(PG_FUNCTION_ARGS)
    {
        std::ostringstream result;
        result << "Common telegram_api constructors (subset):\n\n";
    
        result << "User/Chat types:\n";
        result << "  0x50ab6179 - userEmpty\n";
        result << "  0x020b1422 - user\n";
        result << "  0x3e11acec - userProfilePhotoEmpty\n";
        result << "  0x80f50a21 - userProfilePhoto\n";
        result << "  0x09db1bc6 - userStatusEmpty\n";
        result << "  0x066afa37 - userStatusOnline\n";
        result << "  0x008c703f - userStatusOffline\n";
        result << "  0x29fccb83 - chatEmpty\n";
        result << "  0xc69f59e1 - chat\n";
        result << "  0xab65ea03 - chatForbidden\n";
        result << "  0x7bff875a - channel\n";
        result << "  0xc7d38976 - channelForbidden\n\n";
    
        result << "Message types:\n";
        result << "  0x83e5de54 - messageEmpty\n";
        result << "  0xe1ba5797 - message\n";
        result << "  0xbe7e8ef3 - messageService\n\n";
    
        result << "Media types:\n";
        result << "  0x3ded6320 - messageMediaEmpty\n";
        result << "  0x695b0f8f - messageMediaPhoto\n";
        result << "  0x56e0d474 - messageMediaGeo\n";
        result << "  0xb8c12661 - messageMediaContact\n";
        result << "  0xc52d939d - messageMediaDocument\n\n";
    
        result << "Update types:\n";
        result << "  0x1f2b3476 - updateNewMessage\n";
        result << "  0x62ba04d9 - updateMessageID\n";
        result << "  0xd17f3a90 - updateDeleteMessages\n";
        result << "  0xb67cb1ed - updateUserTyping\n";
        result << "  0x40f04453 - updateChatUserTyping\n";
        result << "  0x55f65e94 - updateChatParticipants\n";
        result << "  0x07761198 - updateUserStatus\n";
        result << "  0x8e5e9873 - updateUserName\n\n";
    
        result << "Auth types:\n";
        result << "  0x05162463 - resPQ\n";
        result << "  0xf35c6d01 - rpc_result\n";
        result << "  0x2144ca19 - rpc_error\n\n";
    
        result << "Container types:\n";
        result << "  0x1cb5c415 - vector\n";
        result << "  0x3072cfa1 - gzip_packed\n";
        result << "  0x73f1f8dc - msg_container\n\n";
    
        result << "Note: TDLib supports ALL telegram_api constructors (1000+ types).\n";
        result << "This is just a small sample. Use tdlib_identify_constructor() to identify any constructor.\n";
    
        PG_RETURN_TEXT_P(cstring_to_text(result.str().c_str()));
    }
    
    /*
     * tdlib_version - Return TDLib parser version info
     */
    Datum
    tdlib_version(PG_FUNCTION_ARGS)
    {
        td::JsonBuilder json;
        auto obj = json.enter_object();
        obj("extension", "pg_tdlib_parser");
        obj("version", "1.0.0");
        obj("tdlib_integration", true);
        obj("supported_schemas", td::JsonArray({
            td::JsonString("telegram_api"),
            td::JsonString("td_api"),
            td::JsonString("mtproto_api")
        }));
        obj("features", td::JsonArray({
            td::JsonString("Full TL schema support"),
            td::JsonString("Automatic type detection"),
            td::JsonString("Gzip decompression"),
            td::JsonString("All telegram_api types"),
            td::JsonString("All td_api types"),
            td::JsonString("All mtproto_api types"),
            td::JsonString("Polymorphic parsing"),
            td::JsonString("Nested object support"),
            td::JsonString("Vector/array support")
        }));
    
        std::string json_str = json.string_builder().as_cslice().str();
        Datum json_datum = CStringGetDatum(json_str.c_str());
        PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in, json_datum));
    }
    
    } // extern "C"