module GraphQL
  class Type
    getter :name, :description
    def initialize(@name : String = "", @description : String = ""); end
    def self.accepts?(value)
      false
    end
    def self.resolve(args, obj)
      obj
    end
    def resolve(args, obj); self.resolve(args, obj); end
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
    def accepts?(value); self.accepts?(value); end
    def resolve(value); self.resolve(value); end

    def self.accepts?(value : String)
      T.values.map(&.to_s).includes? value
    end

    def self.accepts?(value : Number)
      T.values.includes? value
    end

    def self.resolve(value  : Number)
      value
    end
  end

  def self.cast_to_return(value)
    (value.is_a?(Array) ? value.map{ |v| cast_to_return(v).as(GraphQL::ObjectType::Resolvable::ReturnType) } : value).as(GraphQL::ObjectType::Resolvable::ReturnType)
  end

  # we cant use this type without
  # instantiating it due to
  # https://github.com/crystal-lang/crystal/issues/4353
  class ListType(T) < Type

    def accepts?(values)
      return false unless values.is_a?(Array)
      values.each do |v|
        unless T.accepts?(v)
          return false
        end
      end
      true
    end

    def resolve(selections, obj)
      GraphQL.cast_to_return(
        obj.as(Array).map do |e|
          T.resolve(selections, e)
        end.reject do |e|
          !e.is_a?(GraphQL::ObjectType::Resolvable::ReturnType)
        end
      )
    end

  end
end
