require "./schema_introspection"

module GraphQL
  module Schema
    #
    # The Context that will be created when `Schema::execute` is called
    # and provided as an argument to the field resolution callbacks on
    # Object Types. Can be subclassed and passed manually to `Schema::execute`.
    #
    class Context
      getter :schema
      @max_depth : Int32?
      @depth = 0
      @fragments : Array(Language::FragmentDefinition) = [] of Language::FragmentDefinition
      property :max_depth, :depth, :fragments

      def initialize(@schema : GraphQL::Schema::Schema, @max_depth = nil); end

      def with_self(args)
        yield(args, self)
      end
    end

    private alias QueryReturnType = Array(GraphQL::ObjectType?) | GraphQL::ObjectType | ReturnType | Nil

    #
    # Represents a GraphQL Schema against which queries can be executed.
    #
    class Schema
      include GraphQL::Schema::Introspection
      getter :types, :directive_middlewares,
        :directive_definitions, :max_depth
      property :query_resolver, :mutation_resolver

      # max recursive execution depth
      @max_depth : Int32? = nil

      # holds root query object
      @query_resolver : GraphQL::ObjectType?
      # holds root mutation object
      @mutation_resolver : GraphQL::ObjectType?

      # a index of all types defined in the schema
      @types : Hash(String, Language::TypeDefinition)

      # holds structs for input type parsing
      @input_types = Hash(String, InputType.class).new

      # holds definitions of all directives used in the schema
      @directive_definitions = Hash(String, Language::DirectiveDefinition).new

      # directive middlewares to be evaluated
      # during query execution
      @directive_middlewares = [
        GraphQL::Directives::IncludeDirective.new,
        GraphQL::Directives::SkipDirective.new,
      ]

      # an instance of `GraphQL::TypeValidation`
      # used for validating inputs against the
      # schema definition
      @type_validation : GraphQL::TypeValidation

      #
      # Takes a parsed GraphQL schema definition
      #
      def initialize(@document : Language::Document)
        schema, @types, @directive_definitions = extract_elements

        # substitute TypeNames with type definition
        @query_definition = @types[schema.query]?.as(Language::ObjectTypeDefinition?)

        @type_validation = GraphQL::TypeValidation.new(@types)
      end

      #
      # Descriptions for Scalar Types
      #
      ScalarTypes = {
        {"String", "A String Value"},
        {"Boolean", "A Boolean Value"},
        {"Int", "An Integer Number"},
        {"Float", "A Floating Point Number"},
        {"ID", "An ID"},
      }

      #
      # register a Struct to parse query variables
      # name : the name of the GraphQL Input Type that gets parsed
      # type : the Struct Type to parse the JSON into
      # (has to have the class method from_json see
      # https://crystal-lang.org/api/0.23.1/JSON.html#mapping%28properties%2Cstrict%3Dfalse%29-macro)
      # for more infos
      def add_input_type(name : String, type : InputType.class)
        @input_types[name] = type
      end

      # get a type definition
      #
      def type_resolve(type : String | Language::AbstractNode)
        case type
        when String
          @types[type]
        when Language::TypeName
          @types[type.name]
        else
          type
        end
      end

      private def extract_elements(node = @document)
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

      def resolve
        with self yield
        self
      end

      private def cast_wrap_block(&block : Hash(String, ReturnType) -> _)
        Proc(Hash(String, ReturnType), GraphQL::Schema::Context, QueryReturnType).new do |args, context|
          res = context.with_self args, &block
          (
            res.is_a?(Array) ? res.map(&.as(GraphQL::ObjectType?)) : res
          ).as(QueryReturnType)
        end
      end
    end
  end
end
