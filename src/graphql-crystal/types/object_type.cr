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

  def with_self
    with self yield
  end

  def self.with_self
    with self yield
  end

  # a constant to hold the fields defined for
  # classes extending the module
  # FIELDS = [] of Tuple(Symbol, Object.class, Hash(String, GraphQL::Type.class)?, String)

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
  FIELDS = [] of Tuple(Symbol, Object.class, Hash(String, GraphQL::Type.class)?, String)
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
          self.with_self do
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
        self.with_self do
          \{{body.body}}
        end
      \{% end %}
    end
  end
end

macro define_resolve_field_methods
  macro finished
  # resolve a field to an object using
  # its name and arguments calling the
  # parent class if the field name can't
  # be found
  def self.resolve_field(name : String, arguments)
    \{% if !@type.constant("FIELDS").empty? %}
      case name
      \{% for field in @type.constant("FIELDS") %}
      when "\{{ field[0].id }}" #\{{@type}}
        \{{field[0].id}}_field(arguments)
      \{% end %}
      else
        fields = %{\{{@type.constant("FIELDS")}}}
        raise "couldn't resolve field \"#{name}\" for #{self.name} (#{fields})"
      end
    \{% else %}
      raise "couldn't resolve field \"#{name}\" for #{self.name} (which has no fields at all)"
    \{% end %}
  end

  def resolve_field(name : String, arguments)
    \{% if !@type.constant("FIELDS").empty? %}
      case name
      \{% for field in @type.constant("FIELDS") %}
      when "\{{ field[0].id }}" #\\\\{{@type}}
        \{{field[0].id}}_field(arguments)
      \{% end %}
      else
        raise "couldn't resolve field \"#{name}\" for \{{@type}}"
      end
    \{% else %}
      raise "couldn't resolve field \"#{name}\" for \{{@type}} (which itself has no fields defined)"
    \{% end %}
    end
  end
end

# a macro to redefine this macro wherever
# it is needed.
macro define_object_type_macros(on_instance?)
  define_field_macro({{on_instance?}})
  define_resolve_field_methods
  # Using the values collected in the FIELDS constant construct
  # a NamedTuple representing its values
  #
  def self.fields
    \{{
      ("NamedTuple.new(" + FIELDS.map { |f| "#{f[0].id}: NamedTuple.new(type: #{f[1]}, args: #{f[2]}, description: #{f[3]})" }.join(", ") + ")").id
    }}
  end

  # the make_inherited macro recursively applies itself to
  # reproduce the fields inheritance mechanism in all classes
  # that directly or indirectly inherit from the class that
  # originally extended the module
  macro make_inherited
    macro inherited
      # unfortunately class.is_a?(ObjectType)
      # returns false for object_type classes
      # when it is called in the resolve method
      # of ./object_type_resolvable.cr, this is
      # a workaround
      {% if on_instance? %}
      def self.im_an_object_type!
        true
      end
      {% end %}
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
           when "\\\{{field[0].id}}" #\\\{{@type}}
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
           when "\\\{{field[0].id}}" #\\\{{@type}}
             self.\\\{{field[0].id}}_field(arguments)
        \\\{% end %}
        else
          super(name, arguments)
        end
        \\\{% else %}
          super(name, arguments)
        \\\{% end %}
      end

      # inception
      define_field_macro({{on_instance?}})
      make_inherited
    end
  end
end
