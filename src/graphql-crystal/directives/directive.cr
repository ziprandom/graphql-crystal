require "../schema/middleware"
module GraphQL
  module Directive
    include GraphQL::Schema::Middleware
  end
end
