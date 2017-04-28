require "./object_type_resolvable.cr"
require "./object_type_included.cr"
require "./object_type_extended.cr"

module GraphQL::ObjectType

  macro included
    define_object_type_macros
    extend GraphQL::ObjectType::Resolvable
    # a constant to hold the fields defined for
    # classes extending the module
    FIELDS = [] of Tuple(Symbol, Type.class, Hash(String, Type.class)?)
    make_inherited
  end

  macro extended
    define_object_type_macros
    extend GraphQL::ObjectType::Resolvable
    # a constant to hold the fields defined for
    # classes extending the module
    FIELDS = [] of Tuple(Symbol, Type.class, Hash(String, Type.class)?)
    make_inherited
  end

end

# a macro to redefine this macro wherever
# it is needed.
macro define_object_type_macros
  # resolve a field to an object using
  # its name and arguments calling the
  # parent class if the field name can't
  # be found
  def self.resolve_field(name : String, arguments)
     \{% if !@type.constant("FIELDS").empty? %}
      case name
      \{% for field in @type.constant("FIELDS") %}
      when "\{{ field[0].id }}"
        \{{field[0].id}}_field(arguments)
      \{% end %}
      else
        raise "couldn't resolve field \"#{name}\" for #{{self.name}}"
      end
    \{% else %}
      raise "couldn't resolve field \"#{name}\" for #{{self.name}}"
    \{% end %}
  end

  def resolve_field(name : String, arguments)
     \{% if !@type.constant("FIELDS").empty? %}
      case name
      \{% for field in @type.constant("FIELDS") %}
      when "\{{ field[0].id }}" #\\\{{@type}}
        \{{field[0].id}}_field(arguments)
      \{% end %}
      else
        raise "couldn't resolve field \"#{name}\" for \\\{{@type}}"
      end
    \{% else %}
      raise "couldn't resolve field \"#{name}\" for \\\{{@type}}"
    \{% end %}
  end

  # Using the values collected in the FIELDS constant construct
  # a NamedTuple representing its values
  def self.fields
    \{{ @type.constant("FIELDS") ?
      ("NamedTuple.new(" + @type.constant("FIELDS").map { |f| "#{f[0].id}: NamedTuple.new(type: #{f[1]}, args: #{f[2]})" }.join(", ") + ")").id : nil
    }}
  end

  # the make_inherited macro recursively applies itself to
  # reproduce the fields inheritance mechanism in all classes
  # that directly or indirectly inherit from the class that
  # originally extended the module
  macro make_inherited
    macro inherited
      # classes that inherit from the class that
      # originally extended the module will have their
      # own FIELDS constant hodling only the fields they
      # define themselfes
      \\\{% if !@type.constant("FIELDS") %}
           FIELDS = [] of Tuple(Symbol, Type.class, Hash(String, Type.class)?)
      \\\{% end %}

      # classes that inherit from the class that
      # originally extended the module will return
      # their FIELDS constant converted to a NamedTuple
      # and recursively merged with the NamedTuples
      # representing the FIELDS constants of their parent
      # classes
      def self.fields #\\\{{@type}}
        \\\{{@type.superclass}}.fields.merge(
          \\\{{
            (
              "NamedTuple.new(" + FIELDS.map do |f|
               "#{f[0].id}: NamedTuple.new(type: #{f[1]}, args: #{f[2]})"
              end.join(", ") + ")"
            ).id
          }}
        )
      end

      # resolve a field to an object using
      # its name and arguments calling the
      # parent class if the field name can't
      # be found
      def self.resolve_field(name : String, arguments)
        \\\{% if !FIELDS.empty? %}
        case name
        \\\{% for field in FIELDS %}
           when "\\\{{field[0]}}"
             self.\\\{{field[0].id}}_field(arguments)
        \\\{% end %}
        else
          # super doesn't work here for whatever reason
          # but we have everything we need to manually
          # call the class method on the superclass
          \\\{{@type.superclass}}.resolve_field(name, arguments)
        end
        \\\{% else %}
          \\\{{@type.superclass}}.resolve_field(name, arguments)
        \\\{% end %}
      end

      def resolve_field(name : String, arguments)
        \\\{% if !FIELDS.empty? %}
        case name
        \\\{% for field in FIELDS %}
           when "\\\{{field[0]}}"
             self.\\\{{field[0].id}}_field(arguments)
        \\\{% end %}
        else
          previous_def(name, arguments)
        end
        \\\{% else %}
          previous_def(name, arguments)
        \\\{% end %}
      end

      # inception
      define_field_macro
      make_inherited
    end
  end
end
