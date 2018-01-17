require "./nodes"

module CLTK
  alias TokenValue = String | Float64 | Int32 | Nil
  alias Type = GraphQL::Language::AbstractNode |
               TokenValue |
               Bool |
               Tuple(String, String) |
               Array(Type)
end
