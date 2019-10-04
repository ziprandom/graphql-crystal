class GraphQL::WParser
  property max_nesting = 512

  def initialize(lexer : WLexer)
    @lexer = lexer
  end

  def parse(source : String) : Language::Document
    context = WParserContext.new(source, @lexer)
    context.parse
  end
end