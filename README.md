# graphql-crystal

a graphql parser for the crystal programming language ported from [graphql-ruby](https://github.com/rmosolgo/graphql-ruby) and implemented using the [crystal language toolkit](https://github.com/ziprandom/cltk).

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  graphql-crystal:
    github: ziprandom/graphql-crystal
```

## Usage

```crystal
require "graphql-crystal"

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
document = GraphQL::Language::Parser.parse(
  GraphQL::Language::Lexer.lex(schema_string), {lookahead: false}
).as(GraphQL::Language::Document)

# convert the document back
# to a graphql query string
puts document.to_query_string

# .. or print it's json
# representation
# puts document.to_json
```

## Development

run tests with

```
crystal spec
```

## Contributing

1. Fork it ( https://github.com/ziprandom/graphql-crystal/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [ziprandom](https://github.com/ziprandom)  - creator, maintainer
