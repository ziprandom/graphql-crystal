require "../schema/field_resolver"
module GraphQL
  class Type
    def accepts?(value)
      false
    end

    def self.accepts?(value)
      false
    end

    def self.resolve(args, obj)
      obj
    end

  end

  class StringType < Type
    def self.accepts?(value : String)
      true
    end
  end

  class IntegerType < Type
    def self.accepts?(value : Number)
      true
    end
  end

  class IDType < Type
    def self.accepts?(value : Int)
      true
    end
  end

  class EnumType(T) < Type

    # we convert to string when returning
    def self.resolve(selections, value)
      value.to_s
    end

    # we converto to Int when
    # when parsing
    def self.prepare(value)
      T.parse?(value.name).try(&.to_i)
    end

    def self.accepts?(value : GraphQL::Language::AEnum)
      !!T.parse? value.name
    end

  end

  def self.cast_to_return(value)
    (
      value.is_a?(Array) ?
        value.map{ |v| cast_to_return(v).as(GraphQL::Schema::ReturnType) } :
        value
    ).as(GraphQL::Schema::ReturnType)
  end

  # we cant use this type without
  # instantiating it due to
  # https://github.com/crystal-lang/crystal/issues/4353
  class ListType(T) < Type

    def accepts?(value)
      self.accepts? value
    end

    def self.accepts?(values)
      return false unless values.is_a?(Array)
      values.each do |v|
        unless T.accepts?(v)
          return false
        end
      end
      true
    end

    def self.resolve(selections, obj)
      GraphQL.cast_to_return(
        obj.as(Array).map do |e|
          GraphQL::Schema::FieldResolver.resolve_selections_for_field(
            T, e, selections
          ).as(GraphQL::Schema::ReturnType)
        end
      )
    end
  end
end
