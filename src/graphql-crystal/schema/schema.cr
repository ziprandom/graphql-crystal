module GraphQL
  module Schema
    class Schema

      alias QueryReturnType = ( Array(GraphQL::ObjectType?) | GraphQL::ObjectType | Nil )

      @queries= Hash(String, Proc(Hash(String, ReturnType), QueryReturnType)).new
      @mutations = Hash(String, Proc(Hash(String, ReturnType), QueryReturnType)).new

      @query : Language::ObjectTypeDefinition?
      @mutation : Language::ObjectTypeDefinition?
      @types : Hash(String, Language::TypeDefinition)
      @type_validation : GraphQL::TypeValidation

      def initialize(@document : Language::Document)
        result = extract_elements
        # substitute TypeNames with type definition
        @types = result[:types]
        @query = result[:types][result[:schema].query]?.as(Language::ObjectTypeDefinition?)
        @mutation = result[:types][result[:schema].mutation]?.as(Language::ObjectTypeDefinition?)
        @type_validation = GraphQL::TypeValidation.new(@types)
      end

      ScalarTypes = {
        { "String", "A String Value" },
        { "Boolean", "A Boolean Value" },
        { "Int", "An Integer Number" },
        { "Float", "A Floating Point Number" },
        { "ID", "An ID" }
      }

      def extract_elements(node = @document)
        types = Hash(String, Language::TypeDefinition).new
        schema = uninitialized Language::SchemaDefinition

        ScalarTypes.each do |(type_name, description)|
          types[type_name] = Language::ScalarTypeDefinition.new(
            name: type_name, description: description,
            directives: [] of Language::Directive
          )
        end

        @document.map_children do |node|
            case node
            when Language::SchemaDefinition
              schema = node
            when Language::TypeDefinition
              types[node.name] = node
            end
            node
        end
        {
          schema: schema,
          types: types,
        }
      end

      def resolve_query(name : String, args : Hash(String, ReturnType))
        @queries[name].call(args)
      end

      def resolve_mutation(name : String, args : ReturnType)
        @mutations[name].call(args)
      end

      def resolve
        with self yield
        self
      end

      def cast_wrap_block(block)
        Proc(Hash(String, ReturnType), QueryReturnType).new do |args|
          res = block.call(args)
          (
            res.is_a?(Array) ? res.map(&.as(GraphQL::ObjectType?)) : res
          ).as( QueryReturnType )
        end
      end

      def query(name, &block : Hash(String, ReturnType) -> _ )
        @queries[name.to_s] = cast_wrap_block(block)
      end

      def mutation(name, &block : Hash(String, ReturnType) -> _ )
        @mutations[name.to_s] = cast_wrap_block(block)
      end
    end

  end
end
