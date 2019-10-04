require "string_pool"

class GraphQL::WLexer
  def lex(source : String | IO)
    lex(source, 0)
  end

  def lex(source : String | IO, start_position : Int32) : Token
    context = WLexerContext.new(source, start_position)
    context.get_token
  end
end
