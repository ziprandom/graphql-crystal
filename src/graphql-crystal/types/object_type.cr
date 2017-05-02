require "./object_type_resolvable.cr"

module GraphQL::ObjectType
  macro included
    define_graphql_fields(false)
  end

  macro extended
    define_graphql_fields(true)
  end
end

macro define_graphql_fields(on_instance?)
  extend GraphQL::ObjectType::Resolvable
  define_object_type_macros({{on_instance?}})

  # a constant to hold the fields defined for
  # classes extending the module
  FIELDS = [] of Tuple(Symbol, Type.class, Hash(String, Type.class)?, String)

  # ensure inherited classes
  # behave the way you'd expect
  # them to
  make_inherited
end

# the macro pushes the supplied values onto the FIELDS constant
# and defines a standardised accessor method <fieldname>_field
# to access the value, using the callback as method body, if provided
# and resorting to the instance variable of the same name of no block
# was given (@<field_name>)
macro define_field_macro(on_instance?)
  macro field(*args, &body)
    \{% name = args[0]
        type = args[1]
        description = args[2] || ""
        arguments = args[3]
      %}
    \{% FIELDS << {name, type, arguments, description} %}
    def self.\{{args[0].id}}_field(args)
      {% if on_instance? %}\
      nil
      {% else %}
        args ||= Hash(String, String).new
        \{% if body.is_a? Nop %}\
          nil
        \{% else %}\
          with_self do
            \{{body.body}}
          end
        \{% end %}
      {% end %}\
    end

    def \{{args[0].id}}_field(args)
      args ||= Hash(String, String).new
      \{% if body.is_a? Nop %}
        \{{args[0].id}}
      \{% else %}
        with_self do
          \{{body.body}}
        end
      \{% end %}
    end
  end
end

macro define_resolve_field_methods
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
end

# a macro to redefine this macro wherever
# it is needed.
macro define_object_type_macros(on_instance?)

  define_field_macro({{on_instance?}})
  define_resolve_field_methods
  # Using the values collected in the FIELDS constant construct
  # a NamedTuple representing its values
  def self.fields
    \{{ @type.constant("FIELDS") ?
      ("NamedTuple.new(" + @type.constant("FIELDS").map { |f| "#{f[0].id}: NamedTuple.new(type: #{f[1]}, args: #{f[2]}, description: #{f[3]})" }.join(", ") + ")").id : nil
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
           FIELDS = [] of Tuple(Symbol, Type.class, Hash(String, Type.class)?, String)
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
               "#{f[0].id}: NamedTuple.new(type: #{f[1]}, args: #{f[2]}, description: #{f[3]})"
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
           when "\\\{{field[0].id}}"
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
           when "\\\{{field[0].id}}"
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
      define_field_macro({{on_instance?}})
      make_inherited
    end
  end
end
