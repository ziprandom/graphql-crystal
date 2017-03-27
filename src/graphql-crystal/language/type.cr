require "./nodes"
require "cltk/token"
 module CLTK
   alias Type = GraphQL::Language::AbstractNode       |
                Token                                 |
                Bool                                  |
                String                                |
                Int32                                 |
                Float64                               |
                Nil                                   |
                Hash(String, Type)                    |
                Array(Type)
 end
