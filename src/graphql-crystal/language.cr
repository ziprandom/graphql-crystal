require "./language/lexer"
require "./language/nodes"
require "./language/parser"
require "./language/generation"

module GraphQL::Language
  #
  # Parse a query string and return the Document
  #
  def self.parse(query_string, options = NamedTuple.new) : GraphQL::Language::Document

    tokens =
      aggregate_neighbouring_comments(
        GraphQL::Language::Lexer.lex(query_string)
      )

    GraphQL::Language::Parser.parse(
      tokens, options
    ).as(GraphQL::Language::Document)
  rescue e #: CLTK::Parser::Exceptions::NotInLanguage
    raise e
  end

  #
  #
  private def self.aggregate_neighbouring_comments(tokens)
    first = tokens.shift
    tokens.reduce([first]) do |tokens, token|
      if token.type == :COMMENT && tokens.last.type == :COMMENT
        last = tokens.pop
        tokens << CLTK::Token.new(
          :COMMENT,
          last.value.as(String) + " " + token.value.as(String),
          CLTK::StreamPosition.new(
            last.position.not_nil!.stream_offset, last.position.not_nil!.line_number,
            last.position.not_nil!.line_offset,
            last.position.not_nil!.length +
            token.position.not_nil!.length)
        )
      else
        tokens << token
      end
      tokens
    end
  end
end
