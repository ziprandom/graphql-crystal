# coding: utf-8
module GraphQL
  module Schema

    class Schema

      TYPE_NAME_FIELD = Language::FieldDefinition.new(
        name: "__typename", type: Language::TypeName.new(name: "String"),
        arguments: Array(Language::InputValueDefinition).new,
        directives: Array(Language::Directive).new,
        description: "the name of this GraphQL type"
      )

      def execute(document : String, params = nil)
        execute(Language.parse(document), params, Context.new(self))
      end

      def execute(document : Language::Document, params, context)
        queries, mutations, fragments = extract_request_parts(document)

        query = (queries + mutations).first
        begin
          substitute_variables_from_params(query, params) if params
          query.selections = GraphQL::Schema::FragmentResolver.resolve(
            query.selections.map(&.as(Language::Field)),
            fragments
          ).map &.as(Language::AbstractNode)
        rescue e : Exception
          # we hit an error while resolving fragments
          # no path info atm
          return { "data" => nil, "errors" => [{ "message" => e.message, "path" => [] of String}]}
        end

        root_element, root_element_definition = query.operation_type == "query" ?
                         {query_resolver, @query} : {mutation_resolver, @mutation}

        result, errors = resolve_selections_for(
                  root_element_definition,
                  query.selections.map(&.as(Language::Field)),
                  root_element, context
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

      #
      # Resolve an ObjectTypeDefinition
      #
      def resolve_selections_for(
            object_type : Language::ObjectTypeDefinition,
            selections, resolved : ObjectType, context
          ) : Tuple( ReturnType, Array(Error) )

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
            path: [] of (String|Int32)
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
        prepared_selections.map( &.as(Language::Field) ).each do |selection|

          # get field_definition from definition
          # and resolve
          if field_definition = available_fields.find(
               &.as(Language::FieldDefinition).name.==(selection.name))
            _result, _errors = resolve_selections_for(
                       field_definition, selection,
                       wrap_cb(resolved), context
                     )

          # Add Error if no definition found
          else
            _result = nil
            _errors = [Error.new(
                        message: "field not defined.",
                        path:  Array(String|Int32).new
                      )]
          end


          # field name to use
          field_name = selection._alias || selection.name

          errors += _errors.map do |e|
            Error.new( message: e[:message], path: [field_name] + e[:path] )
          end

          result[field_name] = _result.as(ReturnType)
        end

        {result.as(ReturnType), errors}
      end

      def resolve_selections_for(
            field_definition : Language::FieldDefinition,
            selection : Language::Selection , cb, context
          )
        errors = [] of Error

        # validate arguments and substitute with
        # default values if necessary
        begin
          final_args =
            prepare_args(field_definition.arguments, selection.arguments)
        rescue e: Exception
          errors << Error.new(
            message: e.message || "argument error",
            path: Array(String|Int32).new
          )
          return {nil, errors}
        end

        resolved = begin
                     cb.call(selection.name, final_args, context)
                   rescue e: Exception
                     errors << Error.new(
                       message: e.message || "internal server error",
                       path: [] of Int32|String
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
      def resolve_selections_for(
            field_type : Language::TypeName, selections, resolved, context
          ) : Tuple(ReturnType, Array(Error))
        type_definition = @types[field_type.name]
        case type_definition
        # we can directly apply the selections
        when Language::ObjectTypeDefinition
          resolve_selections_for(type_definition, selections, resolved, context)
        # we need to derive the type from the actual object
        when Language::UnionTypeDefinition, Language::InterfaceTypeDefinition
          # FixMe: this needs to be more flexible of course
          concrete_definition = @types[resolved.as(ObjectType).graphql_type]
          resolve_selections_for(concrete_definition, selections, resolved, context)
        # we already hold the results in our hands :)
        when Language::ScalarTypeDefinition, Language::EnumTypeDefinition
          if resolved.is_a?(ReturnType)
            { resolved.as(ReturnType), [] of Error }
          else
            { nil, [] of Error }
          end
        else
          raise "this type? #{type_definition.inspect}"
        end.as(Tuple(ReturnType, Array(Error)))
      end

      #
      # Resolve a ListType
      #
      def resolve_selections_for(field_type : Language::ListType, selections,
                                 resolved : Array, context) : Tuple(ReturnType, Array(Error))
        errors = Array(Error).new
        inner_type = field_type.of_type

        result = resolved.as(Array).map_with_index do |resolved_element, index|
          res, errs = resolve_selections_for(inner_type, selections, resolved_element, context)
          errors += errs.map { |e| Error.new(message: e[:message], path: [index] + e[:path]) }
          res.as(ReturnType)
        end.as(ReturnType)

        { result, errors }
      end

      def wrap_cb(resolved : ObjectType )
        ->(name : String, args : Hash(String, ReturnType), context : GraphQL::Schema::Context) {
          cast_to_resolvecbreturntype resolved.resolve_field(name, args, context)
        }
      end

      #
      # Resolve A NonNullType
      #
      def resolve_selections_for(
            field_type : Language::NonNullType, selections, resolved, context
          ) : Tuple(ReturnType, Array(Error))
        if resolved == nil
          pp "didn't resolve to a NonNull compatible Object"
          return {nil, [Error.new(message: "internal server error", path: [] of (String|Int32))]}
        end
        resolve_selections_for(field_type.of_type, selections, resolved, context)
      end

      def resolve_selections_for(field_type, selections, resolved, context) : Tuple(ReturnType, Array(Error))
        pp field_type, selections, resolved
        raise "I should have never come here"
      end


      def substitute_variables_from_params(query, params : Hash)

        if (superfluous = params.keys - query.variables.map(&.name)).any?
          raise "unknown variables #{superfluous.join(", ")}"
        end
        errors = [] of Error
        full_params = Hash(String, ReturnType).new
        query.variables
          .as(Array(Language::VariableDefinition))
          .each do |variable_definition|
          default_value = variable_definition.default_value
          default_value = default_value.responds_to? :to_value ? default_value.to_value : default_value
          if !(param = params[variable_definition.name]? || default_value)
            errors << Error.new(message: "missing variable #{variable_definition.name}", path: [] of (String|Int32))
          elsif !@type_validation.accepts?(variable_definition.type, param)
            expected_type_string = Language::Generation.generate(variable_definition.type)
            errors << Error.new(
              message: "variable $#{variable_definition.name} is expected to be of type #{expected_type_string}",
              path: [] of (String|Int32)
            )
          else
            full_params[variable_definition.name] = param.as(ReturnType)
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

      def prepare_args(defined, given)
        if (superfluous = given.reject { |g| defined.any?(&.name.==(g.name)) }) &&
           superfluous.any?
          ## TODO: Custom Exceptions here please
          raise "Unknown argument \"#{superfluous.map(&.name).join(",")}\""
        end
        defined.reduce({} of String => ReturnType) do |args, definition|
          provided = given.find(&.name.==(definition.name))
          provided = provided ? provided.value : definition.default_value
          unless @type_validation.accepts?(definition.type, provided)
            ## TODO: Custom Exceptions here please

            raise %{argument "#{definition.name}" is expected to be of type: \
                    "#{Language::Generation.generate(definition.type)}"}
          end

          value = if provided.responds_to?(:to_value)
                    provided.to_value
                  else
                    provided
                  end
          args[definition.name] = GraphQL::Schema.cast_to_return(value)
          args
        end
      end

      def inline_inline_fragment_selections(type, selections)
        type = type.as(Language::ObjectTypeDefinition)
        selections.reduce([] of Language::Field) do |selections, selection|
          case selection
          when Language::Field
            selections << selection
          when Language::InlineFragment
            if selection.type.as(Language::TypeName).name == type.name
              selections += selection.selections.map(&.as(Language::Field))
            end
          end
          selections
        end
      end

      def extract_request_parts(document)
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

      def wrap_callback_cast_result(block)
        Proc(String, Hash(String, ReturnType), ResolveCBReturnType).new do |name, args|
          res = block.call(name, args)
          cast_to_resolvecbreturntype(res)
        end
      end

      def cast_to_resolvecbreturntype(v)
        case v
        when Array
          v.map { |vv| cast_to_resolvecbreturntype(vv).as(ResolveCBReturnType) }
        when Enum
          v.to_s
        else
          v
        end.as(ResolveCBReturnType)
      end

    end
  end
end
