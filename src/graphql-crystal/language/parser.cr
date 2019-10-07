require "./parser_context"

class GraphQL::Language::Parser
  property max_nesting = 512

  def initialize(lexer : Language::Lexer)
    @lexer = lexer
  end

  def parse(source : String) : Language::Document
    context = Language::ParserContext.new(source, @lexer)
    context.parse
  end
end