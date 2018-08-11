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
        field(\\{{name}}, "", args, "") \\{% if block.is_a?(Block)%} \\{{block}}\\{%end%}
      end

      macro field(name, description, args, typename, &block)
        \\{% GRAPHQL_FIELDS << {name, description, args, typename} %}
        private def \\{{name.id}}_field(\\{{(block.is_a?(Block) && block.args.size > 0) ? block.args.first.id : args}}, \\{{((block.is_a?(Block) && block.args.size > 1) ? block.args[1].id : "context").id}})
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
        #
        # resolve a named field on this object with query arguments and context
        #
        def resolve_field(name : String, arguments, context : ::GraphQL::Schema::Context)
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

macro def_graphql_type(extended = false)
  {% unless @type.methods.any? &.name.==("graphql_type") %}
    #
    # get the GraphQL name of this object.
    # defaults to the class name
    #
    def {{extended ? "self.".id : "".id}}graphql_type
      "{{@type.name.gsub(/^(.*::)/, "")}}"
    end
  {% end %}
end

module GraphQL
  #
  # module to be included or extended by Classes and Modules
  # to make them act as GraphQL Objects. Provides the
  # `field` Macro for defining GraphQL Type Fields.
  #
  # ```crystal
  # class MyType
  #   getter :name
  #   def initialize(@name : String, @email : String); end
  #
  #   includes GraphQL::ObjectType
  #   field :name  # with no further arguments
  #                # the field will resolve to
  #                # the getter method of the
  #                # same name
  #
  #   field :email { @email } # a block can be provided
  #                           # to access instance vars
  #
  #   # a block will be called with an arguments hash
  #   # and the context of the graphql request
  #   field :signature do |args, context|
  #     "#{@name} - #{args['with_email']? ? @email : ""}"
  #   end
  #
  # end
  # ```
  #
  module ObjectType
    #
    # get the GraphQL name of this object.
    # defaults to the class name
    #
    def graphql_type
      {{@type.name.gsub(/^(.*::)/, "").stringify}}
    end

    #
    # setter
    # can be used to set GraphQL name of the
    # Object. Defaults to the class name. Is
    # used in introspection queries
    #
    macro graphql_type(name)
      def graphql_type
        {{name}}
      end
    end

    #
    # setter that takes a block.
    # can be used to set GraphQL name of the
    # Object. Defaults to the class name. Is
    # used in introspection queries.
    #
    macro graphql_type(&block)
      {% if block.is_a?(Block) %}
        def graphql_type
          {{block.body}}
        end
      {% end %}
    end

    #
    # This method gets called when a field is resolved
    # on this object. The method gets automatically created
    # for every ObjectType
    #
    def resolve_field(name, arguments, context)
      pp "field not defined", name, self.class
      raise "field #{name} is not defined for #{self.class.name}"
    end

    macro included
      on_included
      macro inherited
        on_included
      end
    end
  end
end
