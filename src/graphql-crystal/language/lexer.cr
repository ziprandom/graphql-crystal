require "string_pool"
require "./token"
require "./lexer_context"

class GraphQL::Language::Lexer
  def lex(source : String | IO)
    lex(source, 0)
  end

  def lex(source : String | IO, start_position : Int32) : Token
    context = Language::LexerContext.new(source, start_position)
    context.get_token
  end

  def self.lex(source : String | IO)
    GraphQL::Language::Lexer.new.lex(source)
  end
end
