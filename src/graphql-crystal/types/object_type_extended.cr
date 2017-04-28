module GraphQL
  # A module to turn a class into a graphql ObjectType
  module ObjectType

    macro extended
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
\\{% end %}
              nil
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

      # enter the matrix
      define_field_macro
    end
  end
end
