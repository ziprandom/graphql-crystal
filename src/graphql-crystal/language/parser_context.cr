require "./token"

class GraphQL::Language::ParserContext
  @current_token : Token
  @comments = [] of String

  def initialize(source : String, lexer : Language::Lexer)
    @source = source
    @lexer = lexer

    @current_token = @lexer.lex(@source)
  end

  def parse
    parse_document
  end

  def dispose
    raise Exception.new("ParserContext has {comments.Count} not applied comments.") if (comments.Count > 0)
  end

  def get_comment
    @comments.size > 0 ? @comments.pop() : nil
  end

  private def advance
    @current_token = @lexer.lex(@source, @current_token.end_position)
  end

  private def advance_through_colon_and_parse_type
    expect(Token::Kind::COLON)
    parse_type
  end

  private def any(open : Token::Kind, next_proc : Proc(T), close : Token::Kind) : Array(T) forall T
    expect(open)

    parse_comment

    nodes = [] of T
    while !skip(close)
      nodes.push(next_proc.call)
    end

    nodes
  end

  private def create_document(start, definitions)
    Language::Document.new(
      # Language::Location.new(start, @current_token.end_position),
      definitions
    )
  end

  private def create_field(start, name, f_alias) : Language::Field
    Language::Field.new(
      name: name,
      _alias: f_alias,
      arguments: parse_arguments,
      directives: parse_directives,
      selections: peek(Token::Kind::BRACE_L) ? parse_selection_set : [] of String
    )
  end

  private def create_graphql_fragment_spread(start)
    Language::FragmentSpread.new(
      parse_fragment_name,
      parse_directives,
    )
  end

  private def create_inline_fragment(start)
    Language::InlineFragment.new(
      
      get_type_condition,
      parse_directives,
      parse_selection_set,
    )
  end

  private def create_operation_definition(start, operation, name)
    comment = get_comment
    Language::OperationDefinition.new(
      operation_type: operation,
      name: name,
      variables: parse_variable_definitions,
      directives: parse_directives,
      selections: parse_selection_set,
    )
  end

  private def create_operation_definition(start)
    comment = get_comment
    Language::OperationDefinition.new(
      operation_type: "query",
      name: nil,
      variables: parse_variable_definitions,
      directives: [] of Language::Directive,
      selections: parse_selection_set,
    )
  end

  private def expect(kind)
    if (@current_token.kind == kind)
      advance
    else
      raise Exception.new("Expected #{Token.get_token_kind_description(kind)}, found #{@current_token.kind} #{@current_token.value}")
    end
  end

  private def expect_colon_and_parse_value_literal(is_constant)
    expect(Token::Kind::COLON)
    parse_value_literal(is_constant)
  end

  private def expect_keyword(keyword)
    token = @current_token
    if token.kind == Token::Kind::NAME && token.value == keyword
      advance
      return
    end

    raise Exception.new("Expected \"#{keyword}\", found Name \"#{token.value}\"");
  end

  private def expect_on_keyword_and_parse_named_type
    expect_keyword("on")
    parse_named_type
  end

  private def get_default_constant_value
    default_value : Language::ArgumentValue?
    if skip(Token::Kind::EQUALS)
      default_value = parse_constant_value
    end

    default_value
  end

  private def get_name
    peek(Token::Kind::NAME) ? parse_name : nil;
  end

  private def get_type_condition
    type_condition = nil
    if @current_token.value != nil && @current_token.value == "on"
      advance
      type_condition = parse_named_type
    end

    type_condition
  end

  private def many(open, next_proc, close)
    expect(open)

    parse_comment

    nodes = [next_proc.call]
    while !skip(close)
      nodes.push(next_proc.call)
    end

    nodes
  end

  private def parse_argument
    comment = get_comment
    start = @current_token.start_position

    Language::Argument.new(
      name: parse_name,
      value: expect_colon_and_parse_value_literal(false),
    )
  end

  private def parse_argument_defs
    if !peek(Token::Kind::PAREN_L)
      return [] of Language::InputValueDefinition;
    end

    many(Token::Kind::PAREN_L, ->{ parse_input_value_def }, Token::Kind::PAREN_R)
  end

  private def parse_arguments
    peek(Token::Kind::PAREN_L) ? many(Token::Kind::PAREN_L, -> { parse_argument }, Token::Kind::PAREN_R) : [] of Language::Argument
  end

  private def parse_boolean_value(token)
    advance
    token.value == "true"
  end

  private def parse_constant_value : Language::ArgumentValue
    parse_value_literal(true)
  end

  private def parse_definition
    parse_comment

    if peek(Token::Kind::BRACE_L)
      return parse_operation_definition
    end

    if peek(Token::Kind::NAME)
      definition = parse_named_definition
      if !definition.nil?
        return definition
      end
    end

    raise Exception.new("Unexpected #{@current_token.kind} '#{@current_token.value}' at #{@current_token.start_position},#{@current_token.end_position}")
  end

  private def parse_definitions_if_not_eof
    definitions = [] of Language::AbstractNode
    if @current_token.kind != Token::Kind::EOF
      while true
        # yield parse_definition
        definitions.push(parse_definition)
        break unless !skip(Token::Kind::EOF)
      end
    end
    definitions
  end

  private def parse_comment
    if !peek(Token::Kind::COMMENT)
      return nil
    end

    text = [] of String?
    start = @current_token.start_position
    end_position : Int32

    while true
      text.push(@current_token.value)
      end_position = @current_token.end_position
      advance
      break unless @current_token.kind == Token::Kind::COMMENT
    end

    comment = text.join("\n")
    @comments.push(comment)
    comment
  end

  private def parse_directive
    start = @current_token.start_position
    expect(Token::Kind::AT)
    Language::Directive.new(
      name: parse_name,
      arguments: parse_arguments,
      
    )
  end

  private def parse_directive_definition
    comment = get_comment
    start = @current_token.start_position
    expect_keyword("directive")
    expect(Token::Kind::AT)

    name = parse_name
    args = parse_argument_defs

    expect_keyword("on")
    locations = parse_directive_locations

    Language::DirectiveDefinition.new(
      name: name,
      arguments: args,
      locations: locations,
      description: comment
    )
  end

  private def parse_directive_locations
    locations = [] of String?

    while true
      locations.push(parse_name)
      break unless skip(Token::Kind::PIPE)
    end

    locations
  end

  private def parse_directives
    directives = [] of Language::Directive
    while peek(Token::Kind::AT)
      directives.push(parse_directive)
    end

    directives
  end

  private def parse_document
    start = @current_token.start_position
    definitions = parse_definitions_if_not_eof

    create_document(start, definitions)
  end

  private def parse_enum_type_definition
    comment = get_comment
    start = @current_token.start_position
    expect_keyword("enum")

    Language::EnumTypeDefinition.new(
      name: parse_name,
      directives: parse_directives,
      fvalues: many(Token::Kind::BRACE_L, ->{ parse_enum_value_definition }, Token::Kind::BRACE_R),
      description: comment,
    )
  end

  private def parse_enum_value(token)
    advance
    Language::AEnum.new(name: token.value)
  end

  private def parse_enum_value_definition
    comment = get_comment
    start = @current_token.start_position

    Language::EnumValueDefinition.new(
      name: parse_name,
      directives: parse_directives,
      selection: nil,
      description: comment,
    )
  end

  private def parse_field_definition
    comment = get_comment
    start = @current_token.start_position
    name = parse_name
    args = parse_argument_defs
    expect(Token::Kind::COLON)

    Language::FieldDefinition.new(
      name: name,
      arguments: args,
      type: parse_type,
      directives: parse_directives,
      description: comment,
    )
  end

  private def parse_field_selection
    start = @current_token.start_position
    name_or_alias = parse_name
    name = nil
    f_alias = nil

    if skip(Token::Kind::COLON)
      name = parse_name
      f_alias = name_or_alias
    else
      f_alias = nil
      name = name_or_alias
    end

    create_field(start, name, f_alias)
  end

  private def parse_float(is_constant) : Float64?
    token = @current_token
    advance
    token.value.not_nil!.to_f64? if !token.value.nil?
  end

  private def parse_fragment
    start = @current_token.start_position
    expect(Token::Kind::SPREAD)

    if peek(Token::Kind::NAME) && !@current_token.value. == "on"
      return create_graphql_fragment_spread(start)
    end

    create_inline_fragment(start)
  end

  private def parse_fragment_definition
    comment = get_comment
    start = @current_token.start_position
    expect_keyword("fragment")

    Language::FragmentDefinition.new(
      name: parse_fragment_name,
      type: expect_on_keyword_and_parse_named_type,
      directives: parse_directives,
      selections: parse_selection_set,
    )
  end

  private def parse_fragment_name
    # raise Exception.new("Unexpected #{@current_token.kind}") if @current_token.value == "on"

    if @current_token.value == "on"
      return nil
    end

    parse_name
  end

  private def parse_implements_interfaces
    types = [] of String?
    if @current_token.value == "implements"
      advance

      while true
        types.push(parse_name)
        break unless peek(Token::Kind::NAME)
      end
    end

    types
  end

  private def parse_input_object_type_definition
    comment = get_comment
    start = @current_token.start_position
    expect_keyword("input")

    Language::InputObjectTypeDefinition.new(
      name: parse_name,
      directives: parse_directives(),
      fields: any(Token::Kind::BRACE_L, ->{ parse_input_value_def }, Token::Kind::BRACE_R),
      description: comment,
    )
  end

  private def parse_input_value_def
    comment = get_comment
    start = @current_token.start_position
    name = parse_name;
    expect(Token::Kind::COLON);

    Language::InputValueDefinition.new(
      name: name,
      type: parse_type,
      default_value: Language.to_fvalue(get_default_constant_value),
      directives: parse_directives,
      description: comment,
    )
  end

  private def parse_int(is_constant) : Int32?
    token = @current_token
    advance
    token.value.not_nil!.to_i32? if !token.value.nil?
  end

  private def parse_interface_type_definition
    comment = get_comment
    start = @current_token.start_position
    expect_keyword("interface")

    Language::InterfaceTypeDefinition.new(
      name: parse_name,
      directives: parse_directives,
      fields: any(Token::Kind::BRACE_L, ->{ parse_field_definition }, Token::Kind::BRACE_R),
      description: comment,
    )
  end

  private def parse_list(is_constant) : Language::ArgumentValue
    start = @current_token.start_position
    constant = Proc(Language::ArgumentValue).new { parse_constant_value }
    value = Proc(Language::ArgumentValue).new { parse_value_value }

    any(Token::Kind::BRACKET_L, is_constant ? constant : value, Token::Kind::BRACKET_R)
  end

  private def parse_name : String?
    start = @current_token.start_position
    value = @current_token.value

    expect(Token::Kind::NAME)
    value
  end

  private def parse_named_definition
    case @current_token.value
    when "query", "mutation", "subscription"
      parse_operation_definition
    when "fragment"
      parse_fragment_definition
    when "schema"
      parse_schema_definition
    when "scalar"
      parse_scalar_type_definition
    when "type"
      parse_object_type_definition
    when "interface"
      parse_interface_type_definition
    when "union"
      parse_union_type_definition
    when "enum"
      parse_enum_type_definition
    when "input"
      parse_input_object_type_definition
    # when "extend"
    #   parse_type_extension_definition
    when "directive"
      parse_directive_definition
    else
      nil
    end
  end

  private def parse_named_type : Language::TypeName
    start = @current_token.start_position
    Language::TypeName.new(name: parse_name)
  end

  private def parse_name_value(is_constant)
    token = @current_token;

    if token.value == "true" || token.value == "false"
      return parse_boolean_value(token)
    elsif !token.value.nil?
      if token.value == "null"
        return parse_null_value(token)
      else
        return parse_enum_value(token)
      end
    end

    raise Exception.new("Unexpected #{@current_token}")
  end

  private def parse_object(is_constant)
    comment = get_comment
    start = @current_token.start_position

    Language::InputObject.new(arguments: parse_object_fields(is_constant))
  end

  private def parse_null_value(token)
    advance
    nil
  end

  private def parse_object_field(is_constant)
    comment = get_comment
    start = @current_token.start_position
    Language::Argument.new(
      name: parse_name,
      value: expect_colon_and_parse_value_literal(is_constant)
    )
  end

  private def parse_object_fields(is_constant)
    fields = [] of Language::Argument

    expect(Token::Kind::BRACE_L)
    while !skip(Token::Kind::BRACE_R)
      fields.push(parse_object_field(is_constant))
    end

    fields
  end

  private def parse_object_type_definition
    comment = get_comment

    start = @current_token.start_position
    expect_keyword("type")

    Language::ObjectTypeDefinition.new(
      name: parse_name,
      description: comment,
      interfaces: parse_implements_interfaces,
      directives: parse_directives,
      fields: any(Token::Kind::BRACE_L, ->{ parse_field_definition }, Token::Kind::BRACE_R),
    )
  end

  private def parse_operation_definition
    start = @current_token.start_position

    if peek(Token::Kind::BRACE_L)
      return create_operation_definition(start)
    end

    create_operation_definition(start, parse_operation_type, get_name);
  end

  private def parse_operation_type
    token = @current_token
    expect(Token::Kind::NAME)
    token.value || "query"
  end

  private def parse_operation_type_definition
    start = @current_token.start_position
    operation = parse_operation_type
    expect(Token::Kind::COLON)
    type = parse_named_type

    Tuple.new(operation, type)
  end

  private def parse_scalar_type_definition
    comment = get_comment
    start = @current_token.start_position
    expect_keyword("scalar")
    name = parse_name
    directives = parse_directives

    Language::ScalarTypeDefinition.new(
      name: name,
      directives: directives,
      description: comment,
    )
  end

  private def parse_schema_definition
    comment = get_comment
    start = @current_token.start_position
    expect_keyword("schema")
    directives = parse_directives
    definitions = many(Token::Kind::BRACE_L, ->{ parse_operation_type_definition }, Token::Kind::BRACE_R)

    definitions = definitions.as(Array).reduce(Hash(String, String).new) do |memo, pair|
      pair.as(Tuple(String, GraphQL::Language::TypeName)).tap { |pair| memo[pair[0]] = pair[1].name }
      memo
    end

    Language::SchemaDefinition.new(
      query: definitions["query"]?,
      mutation: definitions["mutation"]?,
      subscription: definitions["subscription"]?
    )
  end

  private def parse_selection
    return peek(Token::Kind::SPREAD) ? parse_fragment : parse_field_selection
  end

  private def parse_selection_set
    start = @current_token.start_position
    many(Token::Kind::BRACE_L, ->{ parse_selection }, Token::Kind::BRACE_R)
  end

  private def parse_string(is_constant)
    token = @current_token
    advance
    token.value
  end

  private def parse_type
    type = nil
    start = @current_token.start_position
    if skip(Token::Kind::BRACKET_L)
      type = parse_type
      expect(Token::Kind::BRACKET_R)
      type = Language::ListType.new(of_type: type)
    else
      type = parse_named_type
    end

    if skip(Token::Kind::BANG)
      return Language::NonNullType.new(of_type: type)
    end

    type
  end

  # private def parse_type_extension_definition
  #   comment = get_comment
  #   start = @current_token.start_position
  #   expect_keyword("extend")
  #   definition = parse_object_type_definition

  #   Language::TypeExtensionDefinition.new(
  #     definition: definition,
  #   )
  # end

  private def parse_union_members
    members = [] of Language::TypeName

    while
      members.push(Language::TypeName.new(name: parse_named_type.name))
      break unless skip(Token::Kind::PIPE)
    end

    members
  end

  private def parse_union_type_definition
    comment = get_comment
    start = @current_token.start_position
    expect_keyword("union")
    name = parse_name
    directives = parse_directives
    expect(Token::Kind::EQUALS)
    types = parse_union_members

    Language::UnionTypeDefinition.new(
      name: name,
      directives: directives,
      types: types,
      description: comment,
    )
  end

  private def parse_value_literal(is_constant) : Language::ArgumentValue
    token = @current_token

    case token.kind
    when Token::Kind::BRACKET_L
      return parse_list(is_constant)
    when Token::Kind::BRACE_L
      return parse_object(is_constant)
    when Token::Kind::INT
      return parse_int(is_constant)
    when Token::Kind::FLOAT
      return parse_float(is_constant)
    when Token::Kind::STRING
      return parse_string(is_constant)
    when Token::Kind::NAME
      return parse_name_value(is_constant)
    when Token::Kind::DOLLAR
      return parse_variable if !is_constant
    end

    raise Exception.new("Unexpected #{@current_token.kind} at #{@current_token.start_position} near #{@source[@current_token.start_position-15,30]}")
  end

  private def parse_value_value : Language::ArgumentValue
    parse_value_literal(false)
  end

  private def parse_variable
    start = @current_token.start_position
    expect(Token::Kind::DOLLAR)

    Language::VariableIdentifier.new(name: get_name)
  end

  private def parse_variable_definition : Language::VariableDefinition
    start = @current_token.start_position
    Language::VariableDefinition.new(
      name: parse_variable.name,
      type: advance_through_colon_and_parse_type,
      default_value: skip_equals_and_parse_value_literal
    )
  end

  private def parse_variable_definitions : Array(Language::VariableDefinition)
    return peek(Token::Kind::PAREN_L) ?
      many(Token::Kind::PAREN_L, ->{ parse_variable_definition }, Token::Kind::PAREN_R) :
      [] of Language::VariableDefinition
  end

  private def peek(kind)
    @current_token.kind == kind
  end

  private def skip(kind)
    parse_comment
    is_current_token_matching = @current_token.kind == kind
    advance if is_current_token_matching
    is_current_token_matching
  end

  private def skip_equals_and_parse_value_literal
    skip(Token::Kind::EQUALS) ? parse_value_literal(true) : nil
  end
end
