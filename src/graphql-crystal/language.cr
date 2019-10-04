require "./language/lexer"
require "./language/nodes"
require "./language/parser"
require "./language/generation"

module GraphQL::Language
  #
  # Parse a query string and return the Document
  #
  def self.parse_with_cltk(query_string, options = NamedTuple.new) : GraphQL::Language::Document
    GraphQL::Language::Parser.parse(
      GraphQL::Language::Lexer.lex(query_string), options
    ).as(GraphQL::Language::Document)
  rescue e #: CLTK::Parser::Exceptions::NotInLanguage
    raise e
  end

  def self.parse(query_string, options = NamedTuple.new) : GraphQL::Language::Document
    GraphQL::WParser.new(
      GraphQL::WLexer.new
    ).parse(query_string)
  rescue e #: CLTK::Parser::Exceptions::NotInLanguage
    raise e
  end

end
