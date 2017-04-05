@[Link("graphqlparser")]
lib GraphQLParser
  fun parse_string = graphql_parse_string(text : LibC::Char*, error : LibC::Char**) : GraphQlAstNode*
  alias GraphQlAstNode = Void
  fun parse_string_with_experimental_schema_support = graphql_parse_string_with_experimental_schema_support(text : LibC::Char*, error : LibC::Char**) : GraphQlAstNode*
  fun parse_file = graphql_parse_file(file : File*, error : LibC::Char**) : GraphQlAstNode*
  struct X_IoFile
    _flags : LibC::Int
    _io_read_ptr : LibC::Char*
    _io_read_end : LibC::Char*
    _io_read_base : LibC::Char*
    _io_write_base : LibC::Char*
    _io_write_ptr : LibC::Char*
    _io_write_end : LibC::Char*
    _io_buf_base : LibC::Char*
    _io_buf_end : LibC::Char*
    _io_save_base : LibC::Char*
    _io_backup_base : LibC::Char*
    _io_save_end : LibC::Char*
    _markers : X_IoMarker*
    _chain : X_IoFile*
    _fileno : LibC::Int
    _flags2 : LibC::Int
    _old_offset : X__OffT
    _cur_column : LibC::UShort
    _vtable_offset : LibC::Char
    _shortbuf : LibC::Char[1]
    _lock : X_IoLockT*
    _offset : X__Off64T
    __pad1 : Void*
    __pad2 : Void*
    __pad3 : Void*
    __pad4 : Void*
    __pad5 : LibC::Int
    _mode : LibC::Int
    _unused2 : LibC::Char
  end
  type File = X_IoFile
  struct X_IoMarker
    _next : X_IoMarker*
    _sbuf : X_IoFile*
    _pos : LibC::Int
  end
  alias X__OffT = LibC::Long
  alias X_IoLockT = Void
  alias X__Off64T = LibC::Long
  fun parse_file_with_experimental_schema_support = graphql_parse_file_with_experimental_schema_support(file : File*, error : LibC::Char**) : GraphQlAstNode*
  fun error_free = graphql_error_free(error : LibC::Char*)
end
