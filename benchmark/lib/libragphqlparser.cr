# bare skeleton used to create bindings for
# facebooks libgraphqlparser with crystal_lib
@[Include("GraphQLParser.h", prefix: %w(graphql_), flags: "-I/usr/local/include/graphqlparser/c/")]
@[Link(GraphQLParser)]
lib GraphQLParser
end
