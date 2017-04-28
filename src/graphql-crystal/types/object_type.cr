require "./object_type_resolvable.cr"


module GraphQL
  # A module to turn a class into a graphql ObjectType
  module ObjectType

    macro extended
      extend GraphQL::ObjectType::Resolvable
      # a constant to hold the fields defined for
      # classes extending the module
      FIELDS = [] of Tuple(Symbol, Type.class, Hash(String, Type.class)?)

      # the macro pushes the supplied values onto the FIELDS constant
      # and defines a standardised accessor method <fieldname>_field
      # to access the value, using the callback as method body, if provided
      # and resorting to the instance variable of the same name of no block
      # was given (@<field_name>)
      macro define_field_macro
        macro field(*args, &body)
          \\{% name = args[0]
               type = args[1]
               arguments = args[2]
            %}
          \\{% FIELDS << {name, type, arguments} %}

          def self.\\{{args[0].id}}_field(args)
            args ||= Hash(String, String).new
            \\{% if body.is_a? Nop %}

            \\{% else %}
              with_self do
                \\{{body.body}}
              end
            \\{% end %}
          end
          def \\{{args[0].id}}_field(args)
            args ||= Hash(String, String).new
            \\{% if body.is_a? Nop %}
              \\{{args[0].id}}
            \\{% else %}
              with_self do
                \\{{body.body}}
              end
            \\{% end %}
          end
        end
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
          \\{% if !@type.constant("FIELDS") %}
             FIELDS = [] of Tuple(Symbol, Type.class, Hash(String, Type.class)?)
          \\{% end %}

          # classes that inherit from the class that
          # originally extended the module will return
          # their FIELDS constant converted to a NamedTuple
          # and recursively merged with the NamedTuples
          # representing the FIELDS constants of their parent
          # classes
          def self.fields #\\{{@type}}
            \\{{@type.superclass}}.fields.merge(
              \\{{
                   ("NamedTuple.new(" + FIELDS.map { |f| "#{f[0].id}: NamedTuple.new(type: #{f[1]}, args: #{f[2]})" }.join(", ") + ")").id
              }}
            )
          end

          \\{% if !FIELDS.empty? %}
          # resolve a field to an object using
          # its name and arguments calling the
          # parent class if the field name can't
          # be found
          def self.resolve_field(name : String, arguments)
            case name
            \\{% for field in FIELDS %}
            when "\\{{field[0]}}"
              self.\\{{field[0].id}}_field(arguments)
            \\{% end %}
            else
              # super doesn't work here for whatever reason
              # but we have everything we need to manually
              # call the class method on the superclass
              \\{{@type.superclass}}.resolve_field(name, arguments)
            end
          end

          def resolve_field(name : String, arguments)
            case name
            \\{% for field in FIELDS %}
            when "\\{{field[0]}}"
              self.\\{{field[0].id}}_field(arguments)
            \\{% end %}
            else
              raise "cant resolve #{name} for \\{{@type}}"
            end
          end
          \\{% end %}
          # inception
          make_inherited
          define_field_macro
        end
      end

      # enter the matrix
      make_inherited
      define_field_macro

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
          when "\{{ field[0].id }}" #\\{{@type}}
            \{{field[0].id}}_field(arguments)
          \{% end %}
          else
            raise "couldn't resolve field \"#{name}\" for \\{{@type}}"
          end
        \{% else %}
          raise "couldn't resolve field \"#{name}\" for \\{{@type}}"
        \{% end %}
      end

      # Using the values collected in the FIELDS constant construct
      # a NamedTuple representing its values
      def self.fields
        \{{ @type.constant("FIELDS") ?
          ("NamedTuple.new(" + @type.constant("FIELDS").map { |f| "#{f[0].id}: NamedTuple.new(type: #{f[1]}, args: #{f[2]})" }.join(", ") + ")").id : nil
        }}
      end
    end
  end
end
