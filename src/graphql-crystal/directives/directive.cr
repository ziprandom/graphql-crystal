require "../schema/middleware"
module GraphQL
  module Directive
    include GraphQL::Schema::Middleware
    property args : Hash(String, GraphQL::Schema::ReturnType)?
    def call(*args)
      call_next(*args)
    end

  end
end
