require "./token"
require "./lexer_context"
require "./lexer"
require "./parser_context"
require "./parser"

module GraphQL
  def self.parse(graphql_string : String)
    parse_string(graphql_string)
  end

  def self.parse_string(string)
    lexer = WLexer.new
    WParser.new(lexer).parse(string)
  end

  def self.scan(graphql_string)
    scan_string(graphql_string)
  end

  def self.scan_string(graphql_string)
    WLexer.new.lex(graphql_string)
  end
end
