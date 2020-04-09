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
    else
      ""
    end
  end

  def self.get_token_kind_description(kind : Kind::EOF) : String
    "EOF"
  end

  def self.get_token_kind_description(kind : Kind::BANG) : String
    "!"
  end

  def self.get_token_kind_description(kind : Kind::DOLLAR) : String
    "$"
  end

  def self.get_token_kind_description(kind : Kind::PAREN_L) : String
    "("
  end

  def self.get_token_kind_description(kind : Kind::PAREN_R) : String
    ")"
  end

  def self.get_token_kind_description(kind : Kind::SPREAD) : String
    "..."
  end

  def self.get_token_kind_description(kind : Kind::EQUALS) : String
    "="
  end

  def self.get_token_kind_description(kind : Kind::AT) : String
    "@"
  end

  def self.get_token_kind_description(kind : Kind::COLON) : String
    ":"
  end

  def self.get_token_kind_description(kind : Kind::BRACKET_L) : String
    "["
  end

  def self.get_token_kind_description(kind : Kind::BRACKET_R) : String
    "]"
  end

  def self.get_token_kind_description(kind : Kind::BRACE_L) : String
    "{"
  end

  def self.get_token_kind_description(kind : Kind::BRACE_R) : String
    "}"
  end

  def self.get_token_kind_description(kind : Kind::PIPE) : String
    "|"
  end

  def self.get_token_kind_description(kind : Kind::NAME) : String
    "Name"
  end

  def self.get_token_kind_description(kind : Kind::INT) : String
    "Int"
  end

  def self.get_token_kind_description(kind : Kind::FLOAT) : String
    "Float"
  end

  def self.get_token_kind_description(kind : Kind::STRING) : String
    "String"
  end

  def self.get_token_kind_description(kind : Kind::COMMENT) : String
    "#"
  end
end
