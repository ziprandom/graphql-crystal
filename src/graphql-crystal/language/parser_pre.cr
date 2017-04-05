require "./type"
require "./nodes"
require "./lexer"

require "cltk/macros"
require "cltk/parser/parser_concern"
{% puts "creating a prefinalized parser, this takes a lot of time ...".id%}

insert_output_of("graphql parser") do
  require "cltk/parser/crystalize"
  require "./parser"
  GraphQL::Language::Parser.crystalize
end

module GraphQL::Language::Parser
  def self.parse(graphql_string, options)
    parse GraphQL::Language::Lexer.lex(graphql_string), options
  end
end
