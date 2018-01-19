require "../schema/middleware"

module GraphQL
  #
  # A module to be included in a
  # directive to act as a middleware
  #
  module Directive
    include GraphQL::Schema::Middleware
    property args : Hash(String, ReturnType)?

    def call(*args)
      call_next(*args)
    end
  end
end
