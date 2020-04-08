class GraphQL::Language::Token
  enum Kind
    BANG
    DOLLAR
    PAREN_L
    PAREN_R
    SPREAD
    COLON
    EQUALS
    AT
    BRACKET_L
    BRACKET_R
    BRACE_L
    PIPE
    BRACE_R
    NAME
    INT
    FLOAT
    STRING
    BLOCK_STRING
    COMMENT
    AMP
    EOF
  end

  property kind : Kind
  property start_position : Int32
  property end_position : Int32
  property value : String?

  def initialize(kind, value, start_position, end_position)
    @kind = kind
    @start_position = start_position
    @end_position = end_position
    @value = value
  end

  def self.get_token_kind_description(kind : Kind) : String
    case kind
    when Kind::EOF
      "EOF"
    when Kind::BANG
      "!"
    when Kind::DOLLAR
      "$"
    when Kind::PAREN_L
      "("
    when Kind::PAREN_R
      ")"
    when Kind::SPREAD
      "..."
    when Kind::COLON
      ":"
    when Kind::EQUALS
      "="
    when Kind::AT
      "@"
    when Kind::BRACKET_L
      "["
    when Kind::BRACKET_R
      "]"
    when Kind::BRACE_L
      "{"
    when Kind::PIPE
      "|"
    when Kind::BRACE_R
      "}"
    when Kind::NAME
      "Name"
    when Kind::INT
      "Int"
    when Kind::FLOAT
      "Float"
    when Kind::STRING
      "String"
    when Kind::COMMENT
      "#"
    else
      ""
    end
  end
end
