macro on_all_child_classes(&block)

  macro injection
    {{block && block.body}}
  end

  macro inject
    injection
    macro inherited
      injection
    end
  end

  inject
end

macro on_included_s(&block)
  {{ block.body.stringify.id }}
end

macro on_included
  on_included_s do
    on_all_child_classes do
      GRAPHQL_FIELDS = [] of Tuple(Symbol, String, Hash(String, String)?, String)
    end

    on_all_child_classes do

      macro field(name, &block)
        field(\\{{name}}, "", nil, "") \\{% if block.is_a?(Block)%} \\{{block}}\\{%end%}
      end

      macro field(name, description, args, typename, &block)
        \\{% GRAPHQL_FIELDS << {name, description, args, typename} %}
        def \\{{name.id}}_field(\\{{(block.is_a?(Block) && block.args.size > 0) ? block.args.first.id : args}}, \\{{((block.is_a?(Block) && block.args.size > 1) ? block.args[1].id : "context").id}})
          \\{% if block.is_a?(Block) %}
              context.with_self(\\{{(block.is_a?(Block) && block.args.size > 0) ? block.args.first.id : args}}) do
                \\{{block.body}}
              end
          \\{% else %}
            \\{{name.id}}
          \\{% end %}
        end
      end
    end

    on_all_child_classes do
      field :__typename { self.graphql_type }
    end

    on_all_child_classes do
      macro finished
        def resolve_field(name : String, arguments, context)
          \\{% prev_def = @type.methods.find(&.name.==("resolve_field")) %}
          \\{% if !GRAPHQL_FIELDS.empty? %}
              case name
                  \\{% for field in @type.constant("GRAPHQL_FIELDS") %}
                    when "\\{{ field[0].id }}" #\\\\\{{@type}}
                      \\{{field[0].id}}_field(arguments, context)
                      \\{% end %}
              else
                \\{% if prev_def.is_a?(Def) %}
                    \\{{prev_def.args.map(&.name).splat}} = name, arguments, context
                    \\{{prev_def.body}}
                \\{% else %}
                  super(name, arguments, context)
                \\{% end %}
              end
          \\{% else %}
             \\{% if prev_def.is_a?(Def) %}
                 \\{{prev_def.args.map(&.name).splat}} = name, arguments, context
                 \\{{prev_def.body}}
             \\{% else %}
               super(name, arguments, context)
             \\{% end %}
          \\{% end %}
        end
      end
    end

  end
end


module GraphQL

  module ObjectType

    macro graphql_type(name)
      def graphql_type
        {{name}}
      end
    end

    macro graphql_type(&block)
      {% if block.is_a?(Block)%}
        def graphql_type
          {{block.body}}
        end
      {% end %}
    end

    def resolve_field(name, arguments, context)
      pp "field not defined", name, self.class
      raise "field #{name} is not defined for #{self.class.name}"
    end

    def graphql_type
      self.class.to_s
    end

    macro included
      on_included
      macro inherited
        on_included
      end
    end
  end
end
