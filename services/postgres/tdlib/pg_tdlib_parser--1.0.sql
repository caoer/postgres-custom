CREATE EXTENSION IF NOT EXISTS pg_mtproto;

-- ============================================================================
-- CORE FUNCTIONS - Works with ALL TDLib Types
-- ============================================================================

-- Universal serialization - accepts ANY valid TDLib type
CREATE OR REPLACE FUNCTION mtproto_serialize_any(json_data JSON)
RETURNS BYTEA
AS 'MODULE_PATHNAME', 'mtproto_serialize_any'
LANGUAGE C STRICT;

COMMENT ON FUNCTION mtproto_serialize_any IS 
'Serializes ANY TDLib type to binary. The @type field in JSON determines the type.
Supports ALL 1000+ TDLib types including:
- Messages: message, messageText, messagePhoto, messageVideo, etc.
- Updates: updateNewMessage, updateChatTitle, updateUserStatus, etc.
- Requests: sendMessage, getChat, searchMessages, etc.
- Objects: user, chat, file, sticker, etc.';

-- Universal deserialization - automatically detects type
CREATE OR REPLACE FUNCTION mtproto_deserialize_any(binary_data BYTEA)
RETURNS JSON
AS 'MODULE_PATHNAME', 'mtproto_deserialize_any'
LANGUAGE C STRICT;

-- List all available TDLib types
CREATE OR REPLACE FUNCTION mtproto_list_types()
RETURNS JSON
AS 'MODULE_PATHNAME', 'mtproto_list_types'
LANGUAGE C STRICT;

-- Check if a type exists
CREATE OR REPLACE FUNCTION mtproto_type_exists(type_name TEXT)
RETURNS BOOLEAN
AS 'MODULE_PATHNAME', 'mtproto_type_exists'
LANGUAGE C STRICT;
