require "./language/lexer"
require "./language/nodes"
require "./language/parser"
require "./language/generation"

module GraphQL::Language
  def self.parse(query_string, options = NamedTuple.new)
    GraphQL::Language::Parser.parse(
      GraphQL::Language::Lexer.lex(
        query_string
      ), options
    ).as(GraphQL::Language::Document)
  rescue e : CLTK::Parser::Exceptions::NotInLanguage
    raise e
  end
end
