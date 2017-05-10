require "../language/nodes"
require "../schema/field_resolver"
module GraphQL

  module ObjectType
    module Resolvable
      alias ArgumentsType = Array(GraphQL::Language::Field|GraphQL::Language::InlineFragment)
      alias ReturnType = String | Int32 | Float64 | Nil | Bool | Array(ReturnType) | Hash(String, ReturnType)

      alias Error = {message: String, path: Array(String|Int32) }

      def resolve(fields : ArgumentsType, obj = nil)
        errors = validate_fields_and_arguments(fields)

        # we don't resolve field selections for
        # an ObjectType if the Object didn't resolve
        # this doesn't work -->here v <-- due to a bug:
        # return nil if self.is_a?(ObjectType) && obj == nil
        # workaround:
        return {nil, [] of Error} if self.responds_to? :im_an_object_type! && obj == nil

        result = flatten_inline_fragments(fields).reduce( Hash(String, ReturnType).new ) do |hash, field|
          field_name = field.alias || field.name

          if errors.any?( &.[:path].try(&.first).== field.name )
            pair = { field_name => nil.as(ReturnType) }
          else
            resolve_enums_to_values(field)
            if field_name == "__typename"
              pair = { "__typename" => self.to_s.as(ReturnType) }
            else
              begin
                res, errs = resolve( field.as(GraphQL::Language::Field) , obj)
              rescue e: Exception
                res = nil
                errors << Error.new(
                  message: e.message || "internal server error",
                  path: [field_name] + Array(String|Int32).new
                )
              end
              if errs
                errors += errs.map { |e| Error.new(
                  message: e[:message],
                  path: ([field_name] + e[:path]).as(Array(String|Int32)) )
                }
              end
              pair = { field_name => res.as(ReturnType) }
            end
          end
          hash.merge( pair.as(Hash(String, ReturnType)) )
        end.as(ReturnType)
        {result, errors}
      end

      def resolve(field : GraphQL::Language::Field, obj = nil)
        entity = if obj && obj.responds_to?(:resolve_field)
                   obj.resolve_field(
                     field.name,
                     arguments_array_to_hash(field.arguments)
                   )
                 else
                   resolve_field(
                     field.name,
                     arguments_array_to_hash(field.arguments)
                   )
                 end
        # this nicely works with extended modules,
        # thereby making them real interfaces in
        # crystals type system
        field_type = self.fields[field.name][:type]
        selections = field.selections.compact_map do |f|
          f if f.is_a?(GraphQL::Language::Field|GraphQL::Language::InlineFragment)
        end
        GraphQL::Schema::FieldResolver.resolve_selections_for_field(
          field_type, entity, selections
        )
      end

      private def flatten_inline_fragments(fields : ArgumentsType)
        fields = fields.compact_map do |field|
          if field.is_a? GraphQL::Language::InlineFragment
            field.type.as(GraphQL::Language::TypeName).name == self.name ?
              field.selections : nil
          else
            field
          end
        end.flatten.map &.as(GraphQL::Language::Field)
        unless fields.any?
          raise "no selections found for this field! \
                 maybe you forgot to define an inline fragment for this type in a union?"
        end
        fields
      end

      private def arguments_array_to_hash(arguments)
        arguments.reduce(nil) do |memo, arg|
          field_pair = {arg.name => arg.value}
          memo ? memo.merge(field_pair) : field_pair
        end
      end

      #
      # Validate the fields and arguments of this QueryField
      # against the definition.
      # TODO: don't raise on the first error but collect them
      #
      private def validate_fields_and_arguments(fields)
        errors = Array(Error).new

        # casting the hard way
        fields = fields.compact_map { |f| f.is_a?(GraphQL::Language::Field) ? f : nil}.reject( &.try(&.name).==("__typename") )

        allowed_field_names = self.fields.keys.map(&.to_s).to_a
        requested_field_names = fields.map(&.name)

        if (non_existent = requested_field_names - allowed_field_names).any?
          errors = errors + non_existent.map do |name|
            Error.new(
              message: "field not defined.",
              path: [name] + Array(String|Int32).new
            )
          end
        end
        #
        # TODO: check fields against .nilable?
        # and report obligaroty fields that are missing
        fields.each do |field|
          # we wan't to ignore inline fragments here
          next unless field.is_a? GraphQL::Language::Field
          next if errors.any?( &.[:path].first.== field.name )
          allowed_arguments = self.fields[field.name][:args] || NamedTuple.new
          field.arguments.each do |arg|
            if !(argument_definition = allowed_arguments[arg.name]?)
              errors << Error.new(
                message: "Unknown argument \"#{arg.name}\"",
                path: [field.name] + Array(String|Int32).new
              )
              next
            end
            field_type = argument_definition.try(&.[:type])
            if !type_accepts_argument?(field_type, arg.as(GraphQL::Language::Argument))
              errors << Error.new(
                message: %{argument "#{arg.name}" is expected to be of Type: "#{field_type}"},
                path: [field.name] + Array(String|Int32).new
              )
            end

            if field_type.responds_to? :enum_type
              arg.value = field_type.enum_type.parse( arg.value.as(GraphQL::Language::AEnum).name )
            end
          end
        end
        return errors
      end

      private def type_accepts_argument?(type, argument)
        value = argument.responds_to? :value ? argument.value : argument
        if type.is_a?(Array)
          return false unless value.is_a?(Array)
          inner_type = type.first
          !value.any? { |v| !type_accepts_argument?(inner_type, v) }
        else
          !!type.try &.accepts? value
        end
      end

      private def resolve_enums_to_values(field : GraphQL::Language::Field)
        field.arguments.each do |arg|
          value = arg.value
          if value.is_a? Array
            arg.value = arg.value.as(Array).map do |v|
              type = self.fields[field.name][:args].try &.[arg.name][:type]
              if type.is_a? Array
                inner_type = type.first
              end
              if v.is_a?(GraphQL::Language::AEnum) && inner_type && inner_type.responds_to?(:prepare)
                  inner_type.prepare(v).as(GraphQL::Language::ArgumentValue)
              else
                v
              end.as(GraphQL::Language::ArgumentValue)
            end.as(GraphQL::Language::ArgumentValue)
          elsif value.is_a?(GraphQL::Language::AEnum) &&
                (type = self.fields[field.name][:args].try &.[arg.name][:type]) &&
                type.responds_to? :prepare
            arg.value = type.prepare(value).as(Int32)
          end
        end
      end

    end
  end
end
