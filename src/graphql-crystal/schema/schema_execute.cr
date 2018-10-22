# coding: utf-8
module GraphQL
  module Schema
    class Schema
      private TYPE_NAME_FIELD = Language::FieldDefinition.new(
        name: "__typename", type: Language::TypeName.new(name: "String"),
        arguments: Array(Language::InputValueDefinition).new,
        directives: Array(Language::Directive).new,
        description: "the name of this GraphQL type"
      )

      {% if compare_versions(Crystal::VERSION, "0.25.0") < 0 %}
        alias JSONType = JSON::Type
      {% else %}
        alias JSONType = Nil | Bool | Int64 | Float64 | String | Array(JSONType) | Hash(String, JSONType)
      {% end %}
      alias ExecuteParams = Hash(String, JSONType) | Hash(String, String | Hash(String, JSONType | Nil))

      #
      # execute a query against the schema
      # `params`: the Hash with main data
      # `context`: *optional* a custom context to be injected in
      #            field callbacks.
      def execute(params = ExecuteParams, context = Context.new(self, max_depth))
        document = params["query"]?.as(String)
        variables = params["variables"]?.as(Hash(String, JSONType)?)
        operation_name = params["operationName"]?.as(String?)

        execute(Language.parse(document), variables, operation_name, context)
      end

      #
      # execute a query against the schema
      # `document`: a string representing the query to be executed
      # `params`: *optional* the query variables as a Hash
      # `operation_name`: *optional* the query or mutation name to be executed
      # `context`: *optional* a custom context to be injected in
      #            field callbacks.
      def execute(document : String, params = nil, operation_name : String? = nil, context = Context.new(self, max_depth))
        execute(Language.parse(document), params, operation_name, context)
      end

      #
      # execute a query against the schema
      # `document`: a parsed query
      # `params`: *optional* the query variables as a Hash
      # `operation_name`: *optional* the query or mutation name to be executed
      # `context`: *optional* a custom context to be injected in
      #            field callbacks.
      def execute(document : Language::Document, params, operation_name : String? = nil, context = Context.new(self, max_depth))
        execute(document, cast_to_jsontype(params), operation_name, context)
      end

      #
      # execute a query against the schema
      # `document`: a parsed query
      # `params`: *optional* the query variables as a JSON::Any
      # `operation_name`: *optional* the query or mutation name to be executed
      # `context`: *optional* a custom context to be injected in
      #            field callbacks.
      def execute(document : Language::Document, params : JSON::Any, operation_name : String?, context = Context.new(self, max_depth))
        execute(document, cast_jsonany_to_jsontype(params), operation_name, context)
      end

      #
      # execute a query against the schema
      # `document`: a parsed query
      # `params`: *optional* the query variables as a Hash
      # `operation_name`: *optional* the query or mutation name to be executed
      # `context`: *optional* a custom context to be injected in
      #            field callbacks.
      def execute(document : Language::Document, params : Hash(String, JSONType)?, operation_name : String?, context = Context.new(self, max_depth))
        queries, mutations, fragments = extract_request_parts(document)
        context.fragments = fragments
        operations = (queries + mutations)
        query =
          if operations.size > 1
            operations.find { |operation| operation.name == operation_name }
          else
            operations.first
          end
        return {"errors" => [{"message" => "Must provide a valid operation name if query contains multiple operations.", "path" => [] of String}]} unless query

        begin
          substitute_variables_from_params(query, params ? params : {} of String => JSONType)
        rescue e : Exception
          # we hit an error while resolving fragments
          # no path info atm
          return {"data" => nil, "errors" => [{"message" => e.message, "path" => [] of String}]}
        end

        root_element, root_element_definition =
          if query.operation_type == "query"
            {query_resolver, @types[query_resolver.try &.graphql_type]}
          else
            {mutation_resolver, @types[mutation_resolver.try &.graphql_type]}
          end

        result, errors = resolve_selections_for(
          root_element_definition,
          query.selections,
          root_element, context
        )

        res = {"data" => result}

        if (errors.any?)
          error_hash = errors.map do |e|
            ["message", "path"].reduce(nil) do |m, k|
              pair = {k => e[k]}
              m ? m.merge(pair) : pair
            end
          end
          res.merge({"errors" => error_hash})
        else
          res
        end
      end

      alias Args = Tuple(Language::AbstractNode, Array(Language::AbstractNode), ResolveCBReturnType, Context)

      private def run_directives(location, *args, &block : *Args -> {ReturnType, Array(Error)})
        if location.responds_to? :directives
          # Find Directive Middlewares for directives invoked on location
          # prepare arguments hash and set it on the direction
          directives = location.directives.compact_map do |directive|
            definition = self.directive_definitions[directive.name].as(Language::DirectiveDefinition)
            directive.arguments.as(Array(Language::Argument))
            self.directive_middlewares.find(&.name.==(directive.name)).tap do |_directive|
              _directive.not_nil!.args = prepare_args(definition.arguments, directive.arguments)
            end
          end

          if directives.empty?
            block.call(*args.as(Args))
          else
            directives.each_cons(2) do |(directive, _next)|
              directive.next = _next
            end
            directives.last.next = block
            directives.first.call(*args.as(Args))
          end
        else
          block.call(*args.as(Args))
        end
      end

      private def resolve_selections_for(field_definition, selections, resolved, context)
        begin
          _selections = GraphQL::Schema::FragmentResolver.resolve(
            selections,
            context.fragments
          )
          _resolve_selections_for(field_definition, _selections.map(&.as(Language::Selection)).as(Array(Language::Selection)), resolved, context)
        rescue e
          {nil, [Error.new(message: e.message.as(String), path: [] of Int32 | String)]}
        end
      end

      #
      # Resolve an ObjectTypeDefinition
      #
      private def _resolve_selections_for(
        object_type : Language::ObjectTypeDefinition,
        selections : Array(Language::Selection), resolved : ObjectType, context
      ) : Tuple(ReturnType, Array(Error))
        context = context.dup
        context.depth += 1

        if context.max_depth && context.depth > context.max_depth.not_nil!
          return ({
            nil,
            [Error.new(message: "max execution depth reached", path: [] of String | Int32)],
          })
        end

        errors = [] of Error
        result = Hash(String, ReturnType).new

        #
        # prepare selections
        #
        prepared_selections = inline_inline_fragment_selections(
          object_type,
          selections
        )

        # error if selections empty
        if prepared_selections.empty?
          errors << Error.new(
            message: "no selections found for this field! maybe you forgot to define an \
                                inline fragment for this type in a union?",
            path: [] of (String | Int32)
          )
          return nil, errors
        end

        #
        # construct all available fields
        #
        available_fields = object_type.fields +
                           object_type.interfaces.map do |iface_name|
                             @types[iface_name].as(Language::InterfaceTypeDefinition).fields
                           end.flatten + [TYPE_NAME_FIELD]

        #
        # Iterate selections fields, validate & resolve
        #
        prepared_selections.map(&.as(Language::Field)).each do |selection|
          # field name to use
          field_name = selection._alias || selection.name

          # get field_definition from definition
          # set result to nil and add error if
          # not present
          if !(field_definition = available_fields.find(&.as(Language::FieldDefinition).name.==(selection.name)))
            result[field_name] = nil

            errors << Error.new(
              message: "field not defined.",
              path: Array(String | Int32).new.unshift field_name
            )
            next
          end

          run_directives(
            selection,
            field_definition.not_nil!,
            selections.map(&.as(Language::AbstractNode)),
            resolved, context
          ) do |_field_definition, _selections, _resolved, _context|
            _result, _errors = resolve_selections_for(
              field_definition, [selection],
              resolved, context
            )
            errors += _errors.map do |e|
              Error.new(message: e[:message], path: [field_name] + e[:path])
            end

            result[field_name] = _result.as(ReturnType)
            {nil, [] of Error}
          end
        end

        {result.as(ReturnType), errors}
      end

      private def _resolve_selections_for(
        field_definition : Language::FieldDefinition,
        selections : Array, resolved : ObjectType, context
      )
        errors = [] of Error
        # validate arguments and substitute with
        # default values if necessary
        selection = selections.first.as(Language::Field)
        begin
          if selection.responds_to? :arguments
            final_args =
              prepare_args(field_definition.arguments, selection.arguments.as(Array(Language::Argument)))
          else
            raise "this sould not have happened"
          end
        rescue e : Exception
          errors << Error.new(
            message: e.message || "argument error",
            path: Array(String | Int32).new
          )
          return {nil, errors}
        end

        resolved = begin
          resolved.resolve_field(selection.name, final_args, context)
        rescue e : Exception
          errors << Error.new(
            message: e.message || "internal server error",
            path: [] of Int32 | String
          )
          return {nil, errors}
        end

        field_type = field_definition.type

        if resolved == nil
          return {nil, errors}
        end

        result, _errors =
          resolve_selections_for(
            field_type, selection.selections,
            resolved, context
          )

        {result, errors + _errors}
      end

      #
      # Resolve a TypeName
      #
      private def _resolve_selections_for(
        field_type : Language::TypeName, selections : Array(Language::Selection), resolved, context
      ) : Tuple(ReturnType, Array(Error))
        type_definition = @types[field_type.name]
        case type_definition
        # we can directly apply the selections
        when Language::ObjectTypeDefinition
          resolve_selections_for(type_definition, selections, resolved, context)
          # we need to derive the type from the actual object
        when Language::UnionTypeDefinition, Language::InterfaceTypeDefinition
          if resolved.is_a? ObjectType
            # FixMe: this needs to be more flexible of course
            concrete_definition = @types[resolved.as(ObjectType).graphql_type]
            resolve_selections_for(concrete_definition, selections, resolved, context)
          end
          # we already hold the results in our hands :)
        when Language::EnumTypeDefinition
          {resolved.to_s, [] of Error}
        when Language::ScalarTypeDefinition
          if resolved.is_a?(ReturnType)
            {resolved.as(ReturnType), [] of Error}
          else
            {nil, [] of Error}
          end
        else
          raise "this type? #{type_definition.inspect}"
        end.as(Tuple(ReturnType, Array(Error)))
      end

      #
      # Resolve a ListType
      #
      private def _resolve_selections_for(field_type : Language::ListType, selections : Array(Language::Selection),
                                          resolved : Array, context) : Tuple(ReturnType, Array(Error))
        errors = Array(Error).new
        inner_type = field_type.of_type

        result = resolved.as(Array).map_with_index do |resolved_element, index|
          res, errs = resolve_selections_for(inner_type, selections, resolved_element, context)
          errors += errs.map { |e| Error.new(message: e[:message], path: [index] + e[:path]) }
          res.as(ReturnType)
        end.as(ReturnType)

        {result, errors}
      end

      def wrap_cb(resolved : ObjectType)
        ->(name : String, args : Hash(String, ReturnType), context : GraphQL::Schema::Context) {
          cast_to_resolvecbreturntype resolved.resolve_field(name, args, context)
        }
      end

      #
      # Resolve A NonNullType
      #
      private def _resolve_selections_for(
        field_type : Language::NonNullType, selections : Array(Language::Selection), resolved, context
      ) : Tuple(ReturnType, Array(Error))
        if resolved == nil
          pp "didn't resolve to a NonNull compatible Object"
          return {nil, [Error.new(message: "internal server error", path: [] of (String | Int32))]}
        end
        resolve_selections_for(field_type.of_type, selections, resolved, context)
      end

      private def _resolve_selections_for(field_type, selections, resolved, context) : Tuple(ReturnType, Array(Error))
        pp field_type, selections, resolved
        raise "I should have never come here"
      end

      private def substitute_variables_from_params(query, params : Hash(String, JSONType))
        if (superfluous = params.keys - query.variables.map(&.name)).any?
          raise "unknown variables #{superfluous.join(", ")}"
        end
        errors = [] of Error
        full_params = Hash(String, ReturnType).new
        query.variables.as(Array(Language::VariableDefinition)).each do |variable_definition|
          if variable_definition.type.is_a?(GraphQL::Language::NonNullType) && !(params.has_key?(variable_definition.name) || variable_definition.default_value)
            errors << Error.new(message: "missing variable #{variable_definition.name}", path: [] of (String | Int32))
            next
          end

          default_value = variable_definition.default_value
          default_value = default_value.responds_to? :to_value ? default_value.to_value : default_value
          param = params.fetch(variable_definition.name, default_value)
          if !@type_validation.accepts?(variable_definition.type, param)
            expected_type_string = Language::Generation.generate(variable_definition.type)
            errors << Error.new(
              message: "variable $#{variable_definition.name} is expected to be of type #{expected_type_string}",
              path: [] of (String | Int32)
            )
          else
            full_params[variable_definition.name] = cast_to_return(param)
          end
        end

        if errors.any?
          raise errors.map(&.[:message]).join(", ")
        end
        # substitute
        query.map_children do |node|
          case node
          when Language::Argument
            value = node.value
            if value.is_a?(Language::VariableIdentifier)
              node.value = full_params[value.name].as(Language::ArgumentValue)
            end
          end
          node
        end
      end

      private def prepare_args(defined : Array(Language::InputValueDefinition), given)
        if (superfluous = given.reject { |g| defined.any?(&.name.==(g.name)) }) &&
           superfluous.any?
          # # TODO: Custom Exceptions here please
          raise "Unknown argument \"#{superfluous.map(&.name).join(",")}\""
        end
        defined.reduce({} of String => ReturnType) do |args, definition|
          provided = given.find(&.name.==(definition.name))
          provided = provided ? provided.value : definition.default_value
          unless @type_validation.accepts?(definition.type, provided)
            # # TODO: Custom Exceptions here please

            raise %{argument "#{definition.name}" is expected to be of type: \
                          "#{Language::Generation.generate(definition.type)}"}
          end

          value = if provided.responds_to?(:to_value)
                    provided.to_value
                  else
                    provided
                  end

          if definition.type.is_a?(Language::TypeName) &&
             (type = @input_types[definition.type.as(Language::TypeName).name]?)
            value = type.from_json(cast_to_jsontype(value).to_json)
          end

          args[definition.name] = cast_to_return(value)
          args
        end
      end

      private def inline_inline_fragment_selections(type, selections)
        type = type.as(Language::ObjectTypeDefinition)
        selections.reduce([] of Language::Field) do |selections, selection|
          case selection
          when Language::Field
            selections << selection
          when Language::InlineFragment
            if selection.type.as(Language::TypeName).name == type.name
              # assign the fragments directive to the field
              # for later evaluation.
              selections += selection.selections.map(&.as(Language::Field).tap { |f| f.directives = selection.directives })
            end
          end
          selections
        end
      end

      private def extract_request_parts(document)
        Tuple.new(
          Array(Language::OperationDefinition).new,
          Array(Language::OperationDefinition).new,
          Array(Language::FragmentDefinition).new
        ).tap do |result|
          document.map_children do |node|
            case node
            when Language::OperationDefinition
              collection = node.operation_type == "query" ? result[0] : result[1]
              collection << node
            when Language::FragmentDefinition
              result[2] << node
            end
            node
          end
        end
      end

      private def wrap_callback_cast_result(block)
        Proc(String, Hash(String, ReturnType), ResolveCBReturnType).new do |name, args|
          res = block.call(name, args)
          cast_to_resolvecbreturntype(res)
        end
      end

      private def cast_to_resolvecbreturntype(v)
        case v
        when Array
          v.map { |vv| cast_to_resolvecbreturntype(vv).as(ResolveCBReturnType) }
        when Enum
          v.to_s
        else
          v
        end.as(ResolveCBReturnType)
      end

      private def cast_jsonany_to_jsontype(v : JSON::Any) : JSONType
        raw = v.raw
        case raw
        when Array
          raw.map{|vv| cast_jsonany_to_jsontype(vv).as(JSONType)}
        when Hash
          raw.keys.reduce(Hash(String, JSONType).new) do |hash, key|
            hash[key] = cast_jsonany_to_jsontype(raw[key])
            hash
          end
        else 
          raw
        end
      end

      private def cast_to_jsontype(v)
        case v
        when Int32
          v.to_i64.as(JSONType)
        when Float32
          v.to_f64.as(JSONType)
        when Array
          v.map { |vv| cast_to_jsontype(vv).as(JSONType) }
        when Hash
          v.keys.reduce(Hash(String, JSONType).new) do |hash, key|
            hash[key] = cast_to_jsontype(v[key])
            hash
          end
        else
          v
        end.as(JSONType)
      end

      private def cast_to_return(value)
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
    end
  end
end
