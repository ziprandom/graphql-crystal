class Type
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

class ListType(T) < Type
  def self.of_type
    {{@type.type_vars.first}}
  end
  def self.resolve(selections, obj : Array)
    obj.map do |e|
      {{@type.type_vars.first}}.resolve(selections, e)
    end.reject do |e|
      !e.is_a?(GraphQL::ObjectType::Resolvable::ReturnType)
    end
  end
end
