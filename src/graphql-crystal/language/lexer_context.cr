class GraphQL::Language::LexerContext
  def initialize(source : String, index : Int32)
    @current_index = index
    @source = source
  end

  def get_token : Token
    return create_eof_token() if @source.nil?

    @current_index = get_position_after_whitespace(@source, @current_index)

    return create_eof_token() if @current_index >= @source.size

    code = @source[@current_index]

    validate_character_code(code)

    token = check_for_punctuation_tokens(code)

    return token unless token.nil?

    return read_comment() if code == '#'
    return read_name() if code.letter? || code == '_'
    return read_number() if code.number? || code == '-'
    return read_string() if code == '"'

    raise Exception.new("Unexpected character '#{code}' at #{@current_index} near #{@source[@current_index-15,30]}")
  end

  def only_hex_in_string(test)
    !!test.match(/\A\b[0-9a-fA-F]+\b\Z/)
  end

  def read_comment : Token
    start = @current_index
    chunk_start = (@current_index += 1)
    
    code = get_code
    value = ""

    while is_not_at_the_end_of_query() && code.ord != 0x000A && code.ord != 0x000D
      code = process_character(pointerof(value), pointerof(chunk_start))
    end

    value += @source[chunk_start, (@current_index - chunk_start)]

    Token.new(Token::Kind::COMMENT, value.strip, start, @current_index + 1)
  end

  def read_number : Token
    is_float = false
    start = @current_index
    code = @source[start]
    code = self.next_code if code == '-'
    next_code_char = code == '0' ? self.next_code : read_digits_from_own_source(code)
    raise Exception.new("Invalid number, unexpected digit after #{code}: #{next_code_char}") if (next_code_char.ord >= 48 && next_code_char.ord <= 57)

    code = next_code_char
    if code == '.'
      is_float = true
      code = read_digits_from_own_source(self.next_code())
    end

    if code == 'E' || code == 'e'
      is_float = true
      code = self.next_code()
      if code == '+' || code == '-'
        code = self.next_code()
      end
      code = read_digits_from_own_source(code)
    end

    is_float ? create_float_token(start)
      : create_int_token(start)
  end

  def read_string : Token
    start = @current_index
    value = process_string_chunks()

    Token.new(Token::Kind::STRING, value, start, @current_index + 1)
  end

  private def is_valid_name_character(code) : Bool
    code == '_' || code.alphanumeric?
  end

  private def append_characters_from_last_chunk(value, chunk_start)
    value + @source[chunk_start, (@current_index - chunk_start - 1)]
  end

  private def append_to_value_by_code(value, code)
    case code
    when '"'
      value += '"'
    when '/'
      value += '/'
    when '\\'
      value += '\\'
    when 'b'
      value += '\b'
    when 'f'
      value += '\f'
    when 'n'
      value += '\n'
    when 'r'
      value += '\r'
    when 't'
      value += '\t'
    when 'u'
      value += get_unicode_char
    else
      raise Exception.new("Invalid character escape sequence: \\#{code}.")
    end
  end

  private def check_for_invalid_characters(code)
    raise Exception.new("Invalid character within String: #{code}.") if code.ord < 0x0020 && code.ord != 0x0009
  end

  private def check_for_punctuation_tokens(code)
    case code
    when '!'
      create_punctuation_token(Token::Kind::BANG, 1)
    when '$'
      create_punctuation_token(Token::Kind::DOLLAR, 1)
    when '('
      create_punctuation_token(Token::Kind::PAREN_L, 1)
    when ')'
      create_punctuation_token(Token::Kind::PAREN_R, 1)
    when '.'
      check_for_spread_operator()
    when ':'
      create_punctuation_token(Token::Kind::COLON, 1)
    when '='
      create_punctuation_token(Token::Kind::EQUALS, 1)
    when '@'
      create_punctuation_token(Token::Kind::AT, 1)
    when '['
      create_punctuation_token(Token::Kind::BRACKET_L, 1)
    when ']'
      create_punctuation_token(Token::Kind::BRACKET_R, 1)
    when '{'
      create_punctuation_token(Token::Kind::BRACE_L, 1)
    when '|'
      create_punctuation_token(Token::Kind::PIPE, 1)
    when '}'
      create_punctuation_token(Token::Kind::BRACE_R, 1)
    end
  end

  private def check_for_spread_operator : Token?
    char1 = @source.size > @current_index + 1 ? @source[@current_index + 1] : 0
    char2 = @source.size > @current_index + 2 ? @source[@current_index + 2] : 0

    return create_punctuation_token(Token::Kind::SPREAD, 3) if char1 == '.' && char2 == '.'
  end

  private def check_string_termination(code)
    raise Exception.new("Unterminated string.") if code != '"'
  end

  private def create_eof_token : Token
    Token.new(Token::Kind::EOF, nil, @current_index, @current_index)
  end

  private def create_float_token(start) : Token
    Token.new(Token::Kind::FLOAT, @source[start, (@current_index - start)], start, @current_index)
  end

  private def create_int_token(start) : Token
    Token.new(Token::Kind::INT, @source[start, (@current_index - start)], start, @current_index)
  end

  private def create_name_token(start) : Token
    Token.new(Token::Kind::NAME, @source[start, (@current_index - start)], start, @current_index)
  end

  private def create_punctuation_token(kind, offset) : Token
    Token.new(kind, nil, @current_index, @current_index + offset)
  end

  private def get_position_after_whitespace(body : String, start)
    position = start

    while position < body.size
      code = body[position]
      case code
      when '\uFEFF', '\t', ' ', '\n', '\r', ','
        position += 1
      else
        return position
      end
    end

    position
  end

  private def get_unicode_char
      if @current_index + 5 > @source.size
        truncated_expression = @source[@current_index, @source.size]
        raise Exception.new("Invalid character escape sequence at EOF: \\#{truncated_expression}.")
      end

      expression = @source[@current_index, 5]

      if !only_hex_in_string(expression[1, expression.size])
        raise Exception.new("Invalid character escape sequence: \\#{expression}.")
      end

      s = next_code.bytes << 12 | next_code.bytes << 8 | next_code.bytes << 4 | next_code.bytes
      String.new(Slice.new(s.to_unsafe, 4))[0]
  end

  private def if_unicode_get_string : String
    return @source.size > @current_index + 5 &&
      only_hex_in_string(@source[(@current_index + 2), 4]) ? @source[@current_index, 6] : null
  end

  private def is_not_at_the_end_of_query
    @current_index < @source.size
  end

  private def next_code
    @current_index += 1
    return is_not_at_the_end_of_query() ? @source[@current_index] : Char::ZERO
  end

  private def process_character(value_ptr, chunk_start_ptr)
    code = get_code
    @current_index += 1

    if code == '\\'
      value_ptr.value = append_to_value_by_code(append_characters_from_last_chunk(value_ptr.value, chunk_start_ptr.value), get_code)

      @current_index += 1
      chunk_start_ptr.value = @current_index
    end

    return get_code
  end

  private def process_string_chunks
    chunk_start = (@current_index += 1)
    code = get_code
    value = ""

    while is_not_at_the_end_of_query() && code.ord != 0x000A && code.ord != 0x000D && code != '"'
      check_for_invalid_characters(code)
      code = process_character(pointerof(value), pointerof(chunk_start))
    end

    check_string_termination(code)
    value += @source[chunk_start, (@current_index - chunk_start)]
    value
  end

  private def read_digits(source, start, first_code)
    body = source
    position = start
    code = first_code

    if !code.number?
      raise Exception.new("Invalid number, expected digit but got: #{resolve_char_name(code)}")
    end

    while true
      code = (position += 1) < body.size ? body[position] : Char::ZERO
      break unless code.number?
    end

    position
  end

  private def read_digits_from_own_source(code)
    @current_index = read_digits(@source, @current_index, code)
    get_code
  end

  private def read_name
    start = @current_index
    code = Char::ZERO

    while true
      @current_index += 1
      code = get_code
      break unless is_not_at_the_end_of_query && is_valid_name_character(code)
    end

    create_name_token(start)
  end

  private def resolve_char_name(code, unicode_string = nil)
    return "<EOF>" if (code == '\0')

    return "\"#{unicode_string}\"" if unicode_string && !unicode_string.blank?
    return "\"#{code}\""
  end

  private def validate_character_code(code)
    i32_code = code.ord
    if (i32_code < 0x0020) && (i32_code != 0x0009) && (i32_code != 0x000A) && (i32_code != 0x000D)
      raise Exception.new("Invalid character \"\\u#{code}\".")
    end
  end

  private def wait_for_end_of_comment(body, position, code)
    while (position += 1) < body.size && (code = body[position]) != 0 && (code.ord > 0x001F || code.ord == 0x0009) && code.ord != 0x000A && code.ord != 0x000D
    end

    return position
  end

  private def get_code
    return is_not_at_the_end_of_query ? @source[@current_index] : Char::ZERO
  end
end