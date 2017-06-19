require "./schema_introspection"
module GraphQL
  module Schema

    class Context

      getter :schema
      @max_depth : Int32?
      @depth = 0
      @fragments : Array(Language::FragmentDefinition) = [] of Language::FragmentDefinition
      property :max_depth, :depth , :fragments

      def initialize(@schema : GraphQL::Schema::Schema, @max_depth = nil); end

      def with_self(args)
        with self yield(args)
      end
    end

    alias QueryReturnType = ( Array(GraphQL::ObjectType?) | GraphQL::ObjectType | ReturnType | Nil )

    class Schema
      include GraphQL::Schema::Introspection
      getter :types, :directive_middlewares, :directive_definitions,
             :query_resolver, :mutation_resolver, :max_depth
      property :query_resolver, :mutation_resolver

      @max_depth : Int32? = nil
      @query : Language::ObjectTypeDefinition?
      @mutation : Language::ObjectTypeDefinition?

      @query_resolver : GraphQL::ObjectType = ResolverObject.new
      @mutation_resolver : GraphQL::ObjectType = ResolverObject.new

      @types : Hash(String, Language::TypeDefinition)
      @directive_definitions = Hash(String, Language::DirectiveDefinition).new
      @directive_middlewares = [
        GraphQL::Directives::IncludeDirective.new,
        GraphQL::Directives::SkipDirective.new
      ]
      @type_validation : GraphQL::TypeValidation

      def initialize(@document : Language::Document)
        schema, @types, @directive_definitions = extract_elements

        # substitute TypeNames with type definition
        @query = @types[schema.query]?.as(Language::ObjectTypeDefinition?)
        @query_resolver.is_a?(ResolverObject) && @query_resolver.as(ResolverObject).name = schema.query

        if schema.mutation
          @mutation = @types[schema.mutation]?.as(Language::ObjectTypeDefinition?)
          @mutation_resolver.is_a?(ResolverObject) && @mutation_resolver.as(ResolverObject).name = schema.mutation.not_nil!
        end

        @type_validation = GraphQL::TypeValidation.new(@types)
      end

      ScalarTypes = {
        { "String", "A String Value" },
        { "Boolean", "A Boolean Value" },
        { "Int", "An Integer Number" },
        { "Float", "A Floating Point Number" },
        { "ID", "An ID" }
      }

      def type_resolve(type_name : String)
        @types[type_name]
      end

      def type_resolve(type : Language::TypeName)
        @types[type.name]
      end

      def type_resolve(type)
        type
      end

      def extract_elements(node = @document)
        types = Hash(String, Language::TypeDefinition).new
        directives = Hash(String, Language::DirectiveDefinition).new

        schema = uninitialized Language::SchemaDefinition

        ScalarTypes.each do |(type_name, description)|
          types[type_name] = Language::ScalarTypeDefinition.new(
            name: type_name, description: description,
            directives: [] of Language::Directive
          )
        end

        node.map_children do |node|
            case node
            when Language::SchemaDefinition
              schema = node
            when Language::TypeDefinition
              types[node.name] = node
            when Language::DirectiveDefinition
              directives[node.name] = node
            end
            node
        end
        return {schema, types, directives}
      end

      def max_depth(@max_depth); end

      def query(name, &block : Hash(String, ReturnType) -> _ )
        qrslv = @query_resolver
        if qrslv.is_a? ResolverObject
          qrslv.cb_hash[name.to_s] = cast_wrap_block(&block)
        end
      end

      def mutation(name, &block : Hash(String, ReturnType) -> _ )
        qrslv = @mutation_resolver
        if qrslv.is_a? ResolverObject
          qrslv.cb_hash[name.to_s] = cast_wrap_block(&block)
        end
      end

      def cast_wrap_block(&block : Hash(String, ReturnType) -> _)
        Proc(Hash(String, ReturnType), GraphQL::Schema::Context, QueryReturnType).new do |args, context|
          res = context.with_self args, &block
          (
            res.is_a?(Array) ? res.map(&.as(GraphQL::ObjectType?)) : res
          ).as( QueryReturnType )
        end
      end

      def resolve
        with self yield
        self
      end
    end

    #
    # A wrapper for the
    # resolve callbacks of the schema
    class ResolverObject
      include GraphQL::ObjectType
      property :cb_hash, :name
      @name = ""
      @cb_hash = Hash(String, Proc(Hash(String, ReturnType), GraphQL::Schema::Context, QueryReturnType)).new

      graphql_type { @name }

      def resolve_field(name, args, context)
        cb = (@cb_hash[name]?)
        cb ? cb.call(args, context) : super(name, args, context)
      end

    end

  end
end
