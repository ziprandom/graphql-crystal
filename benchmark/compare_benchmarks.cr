# use compile time finalized  version
# require "../src/graphql-crystal/language/parser_pre"
require "../src/graphql-crystal/language/parser"
require "../src/graphql-crystal/language/lexer"
require "./lib/libragphqlparserC"
require "benchmark"

schema_string = <<-schema
  schema {
    query: QueryType
    mutation: MutationType
  }

  # Union description
  union AnnotatedUnion @onUnion = A | B

  type Foo implements Bar {
    one: Type
    two(argument: InputType!): Type
    three(argument: InputType, other: String): Int
    four(argument: String = "string"): String
    five(argument: [String] = ["string", "string"]): String
    six(argument: InputType = {key: "value"}): Type
    seven(argument: String = null): Type
  }

  # Scalar description
  scalar CustomScalar

  type AnnotatedObject @onObject(arg: "value") {
    annotatedField(arg: Type = "default" @onArg): Type @onField
  }

  interface Bar {
    one: Type
    four(argument: String = "string"): String
  }

  # Enum description
  enum Site {
    # Enum value description
    DESKTOP
    MOBILE
  }

  interface AnnotatedInterface @onInterface {
    annotatedField(arg: Type @onArg): Type @onField
  }

  union Feed = Story | Article | Advert

  # Input description
  input InputType {
    key: String!
    answer: Int = 42
  }

  union AnnotatedUnion @onUnion = A | B

  scalar CustomScalar

  # Directive description
  directive @skip(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

  scalar AnnotatedScalar @onScalar

  enum Site {
    DESKTOP
    MOBILE
  }

  enum AnnotatedEnum @onEnum {
    ANNOTATED_VALUE @onEnumValue
    OTHER_VALUE
  }

  input InputType {
    key: String!
    answer: Int = 42
  }

  input AnnotatedInput @onInputObjectType {
    annotatedField: Type @onField
  }

  directive @skip(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

  directive @include(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT
schema

# Parse the Schema to a Document ASTNode
Benchmark.ips(warmup: 4, calculation: 10) do |x|

  x.report("c implementation from facebook: ") {
    GraphQLParser.parse_string(schema_string, nil)
  }

  x.report("cltk based implementation: ") {
    GraphQL::Language::Parser.parse(
      GraphQL::Language::Lexer.lex(schema_string)
    )
  }

end
