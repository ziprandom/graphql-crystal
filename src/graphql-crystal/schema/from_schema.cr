require "../language"
require "../types/type_validation"
require "../schema"
module GraphQL

#  alias Error = {message: String, path: Array(String|Int32) }

  module Schema
    def self.from_schema(schema_string)
      Schema.new GraphQL::Language.parse(schema_string)
    end
  end

  module Schema
    alias ReturnType = String | Int32 | Float64 | Bool | Nil | Array(ReturnType) | Hash(String, ReturnType)
    alias ResolveProc = Hash(String, ReturnType) -> GraphQL::ObjectType?
    alias ResolveCBReturnType = ReturnType | ObjectType | Nil | Array(ResolveCBReturnType)
    class Schema

      def execute(document : String, params = nil)
        execute(GraphQL::Language.parse(document), params)
      end

      def execute(document : GraphQL::Language::Document, params)
        queries, mutations, fragments = extract_request_parts(document)

        query = (queries + mutations).first
        query = GraphQL::Schema.substitute_argument_variables(query, params)

        begin
          query.selections = GraphQL::Schema::FragmentResolver.resolve(
            query.selections.map(&.as(GraphQL::Language::Field)),
            fragments
          ).map &.as(GraphQL::Language::AbstractNode)
        rescue e : Exception
          # we hit an error while resolving fragments
          # no path info atm
          return { "data" => nil, "errors" => [{ "message" => e.message, "path" => [] of String}]}
        end
        field_definition = query.operation_type == "query" ? @query : @mutation
        resolve_cb = query.operation_type == "query" ?
                       ->self.resolve_query(String, Hash(String, ReturnType)) :
                       ->self.resolve_mutation(String, Hash(String, ReturnType))
        result, errors = _execute_query_against_definition(
                  query.selections.map(&.as(GraphQL::Language::Field)),
                  field_definition.not_nil!,
                  resolve_cb
                )
        res = { "data" => result }
        if ( errors.any? )
          error_hash = errors.map do |e|
            ["message", "path"].reduce(nil) do |m, k|
              pair = {k => e[k]}
              m ? m.merge(pair) : pair
            end
          end
          res.merge({ "errors" => error_hash })
        else
          res
        end
      end

      def _execute_query_against_definition(
          selections : Array(GraphQL::Language::Field),
          definition : GraphQL::Language::ObjectTypeDefinition,
          cb : String, Hash(String, ReturnType) -> ResolveCBReturnType
        )
        # Initialize result sets
        errors = Array({message: String, path: Array(String|Int32)}).new
        result = Hash(String, ReturnType).new
        # Iterate selections fields, validate & resolve
        selections.map( &.as(GraphQL::Language::Field) ).each do |selection|
          field_name = selection._alias || selection.name
          # get field_definition from definition
          unless (field_definition = definition.fields.find(
                    &.as(GraphQL::Language::FieldDefinition).name.==(selection.name)))
            errors << Error.new(
              message: "field not defined.",
              path: [field_name] + Array(String|Int32).new
            )
            result[field_name] = nil
            next
          end
          # validate arguments and substitute with
          # default values if necessary
          begin
            final_args = prepare_args(field_definition.arguments, selection.arguments)
          rescue e: Exception
            errors << Error.new(
              message: "invalid arguments provided: #{e.message}",
              path: [field_name] + Array(String|Int32).new
            )
            result[field_name] = nil
            next
          end

          resolved = cb.call(selection.name, final_args)
          field_type = field_definition.type
          resolved_type = case field_type
                          when GraphQL::Language::TypeName
                            @types[field_type.as(GraphQL::Language::TypeName).name]
                          when GraphQL::Language::ListType
                            field_type
                          when GraphQL::Language::NonNullType
                            @types[field_type.of_type.as(GraphQL::Language::TypeName).name]
                          end
          unless resolved
            result[field_name] = nil
            next
          end

          case resolved
          when GraphQL::ObjectType
            resolve_cb = Proc(String, Hash(String, ReturnType), ResolveCBReturnType).new do |name, args|
              res = resolved.as(ObjectType).resolve_field(name, args)
              (res.is_a?(Array) ?
                res.map(&.as(ResolveCBReturnType)) :
                res).as(ResolveCBReturnType)
            end
            res, errs = _execute_query_against_definition(
                   selection.selections.map(&.as(GraphQL::Language::Field)),
                   resolved_type.as(GraphQL::Language::ObjectTypeDefinition),
                   resolve_cb
                 )
          when Array#(GraphQL::ObjectType)
            unless resolved_type.is_a?(GraphQL::Language::ListType)
              raise "internal server error: got array when no ListType but #{resolved_type.inspect} was expected"
              next
            end
            inner_type = resolved_type.of_type
            resolved_type = case inner_type
                            when GraphQL::Language::TypeName
                              @types[inner_type.name]
                            else
                              inner_type
                            end
            errs = [] of Error
            res = resolved.as(Array).map_with_index do |_resolved, index|
              resolve_cb = Proc(String, Hash(String, ReturnType), ResolveCBReturnType).new do |name, args|
                r = _resolved.as(ObjectType).resolve_field(name, args)
                r.is_a?(Array) ?
                  r.map(&.as(ResolveCBReturnType)) : r.as(ResolveCBReturnType)
              end
              if resolved_type.is_a?(GraphQL::Language::ObjectTypeDefinition)
                res, _errs = _execute_query_against_definition(
                       selection.selections.map(&.as(GraphQL::Language::Field)),
                       resolved_type,
                       resolve_cb
                     )
              end
              _errs && _errs.each { |e| errs << Error.new(message: e[:message], path: [index] + e[:path])}
              res.as(ReturnType)
            end
          when ReturnType
            res = resolved.as(ReturnType)
          end
          if errs
            errs.map {|e| errors <<  Error.new(message: e[:message], path: [selection.name] + e[:path] )}
          end
          result[field_name] = res
        end
        {result, errors}
      end

      def prepare_args(defined, given)
        if (superfluous = given.reject { |g| defined.any?(&.name.==(g.name)) }) && superfluous.any?
          ## TODO: Custom Exceptions here please
          raise "superfluous arguments provided: #{superfluous.map(&.name).join(", ")}"
        end
        defined.reduce({} of String => ReturnType) do |args, definition|
          provided = given.find(&.name.==(definition.name))
          provided = provided ? provided.value : definition.default_value
          unless @type_validation.accepts?(definition.type, provided)
            ## TODO: Custom Exceptions here please
            raise "#{definition.type} rejected #{provided}"
          end

          value = if provided.responds_to?(:to_value)
                    provided.to_value
                  else
                    provided
                  end
          args[definition.name] = cast_to_return(value)
          args
        end
      end

      def cast_to_return(value)
        case value
        when Hash
          value.reduce(Hash(String, ReturnType).new) do |memo, h|
            memo[h[0]] = cast_to_return(h[1]).as(ReturnType)
            memo
          end
        when Array
          value.map { |v| cast_to_return(v).as(ReturnType) }
        when GraphQL::Language::AEnum
          value.name
        else
          value
        end.as(ReturnType)
      end

      def extract_request_parts(document)
        Tuple.new(
          Array(GraphQL::Language::OperationDefinition).new,
          Array(GraphQL::Language::OperationDefinition).new,
          Array(GraphQL::Language::FragmentDefinition).new
        ).tap do |result|
          document.map_children do |node|
            case node
            when GraphQL::Language::OperationDefinition
              collection = node.operation_type == "query" ? result[0] : result[1]
              collection << node
            when GraphQL::Language::FragmentDefinition
              result[2] << node
            end
            node
          end
        end
      end

    end

    class Schema
      @queries = Hash(String, ResolveProc).new
      @mutations = Hash(String, ResolveProc).new
      @query : GraphQL::Language::ObjectTypeDefinition?
      @mutation : GraphQL::Language::ObjectTypeDefinition?
      @types : Hash(String, GraphQL::Language::TypeDefinition)
      @type_validation : GraphQL::TypeValidation

      def initialize(@document : GraphQL::Language::Document)
        result = extract_elements
        @types = result[:types]
        @query = result[:types][result[:schema].query]?.as(GraphQL::Language::ObjectTypeDefinition?)
        @mutation = result[:types][result[:schema].mutation]?.as(GraphQL::Language::ObjectTypeDefinition?)
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
        types = Hash(String, GraphQL::Language::TypeDefinition).new
        schema = uninitialized GraphQL::Language::SchemaDefinition

        ScalarTypes.each do |(type_name, description)|
          types[type_name] = GraphQL::Language::ScalarTypeDefinition.new(
            name: type_name, description: description,
            directives: [] of GraphQL::Language::Directive
          )
        end

        @document.map_children do |node|
            case node
            when GraphQL::Language::SchemaDefinition
              schema = node
            when GraphQL::Language::TypeDefinition
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

      def query(name, &block : ResolveProc)
        @queries[name.to_s] = block
      end

      def mutation(name, &block : ResolveProc)
        @mutations[name.to_s] = block
      end
    end
  end
end
