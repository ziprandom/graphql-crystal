module GraphQL
  module Language
    abstract class ASTNode
      macro make_value_methods

        macro accessors(name, type, default)
          def \\{{name}}
            @\\{{name}}
          end

          def \\{{name}}=(@\\{{name}} : \\{{type}}); end
        end

        macro traverse(name, *values)
          \{%
            visit = VISITS.find(&.[0].==(name))
            unless visit
              VISITS << {name, [] of Symbol}
              visit = VISITS.find(&.[0].==(name))
            end
            values.map do |value|
              visit[1] = visit[1] + [value]
            end
          %}
        end

        macro values(args)
          \{%
            args.keys.map do |k|
              VALUES << { k, args[k] }
            end
          %}
          property \{{args.keys.map{|k| "#{k} : #{args[k]}"}.join(", ").id}}
        end

        macro inherited
          make_value_methods
        end
      end

      def self.values
        NamedTuple.new()
      end

      def values
        NamedTuple.new()
      end

      def ==(other)
        self.class == other.class
      end

    #    def inspect
    #      "#{self.class.name}(" +
    #        if vs = values
    #          vs.map do |k, v|
    #            value = if v.is_a?(Array)
    #                      "[" + v.map{ |vv| vv.inspect.as(String) }.join(", ") + "]"
    #                    elsif v.is_a?(Hash)
    #                      "{" + v.map{ |kk, vv| "#{kk.inspect}: #{vv.inspect}".as(String) }.join(", ") + "}"
    #                    else
    #                      v.inspect
    #                    end
    #            "#{k}: #{value}"
    #          end.join(", ")
    #        else
    #          ""
    #        end + ")"
    #    end

      def_clone

      macro inherited

        make_value_methods

        macro finished
          def_clone

          def ==(other : \{{@type}})
            if self.object_id == other.object_id
              true
            else
              \{{ (VALUES.map { |v| "(@#{v[0].id} == other.#{v[0].id})".id } + ["super(other)".id]).join(" && ").id }}
            end
          end

          def self.values
            super\{% if VALUES.size > 0 %}.merge NamedTuple.new(\{{ VALUES.map { |v| "#{v[0].id}: #{v[1].id}".id }.join(",").id }})\{% end %}
          end

          def values
            super\{% if VALUES.size > 0 %}.merge NamedTuple.new(\{{ VALUES.map { |v| "#{v[0].id}: @#{v[0]}".id }.join(",").id }})\{% end %}
          end

          \{% for tuple in  VISITS %}
            \{% key = tuple[0]; elements = tuple[1]%}
            def map_\{{key.id}}(&block : ASTNode -> _)
              visited_ids = [] of UInt64
              visit(\{{key}}, visited_ids, block)
            end
          \{% end %}

          # Recursively apply the given block to each
          # node that gets visited with the given key
          # which nodes get traverses for a given key
          # can be set on a class via the:
          # `traverse :name, :child_1, :child2`
          # macro. If no children are defined for a
          # given traversal path name the block is invoked
          # only with self.
          def visit(name, visited_ids = [] of UInt64, block = Proc(ASTNode, ASTNode?).new {})
            \{% if VISITS.size > 0 %}
            case name
            \{% for tuple in VISITS %}\
              when \{{tuple[0]}}
              \{% for key in tuple[1]%}
                %val = \{{key.id}}
                if %val.is_a?(Array)
                  %result = %val.map! do |v|
                    next v if visited_ids.includes? v.object_id
                    visited_ids << v.object_id
                    res = v.visit(name, visited_ids, block)
                    res.is_a?(ASTNode) ? res : v
                  end
                else
                  unless %val == nil || visited_ids.includes? %val.object_id
                    visited_ids << %val.object_id
                    %result = %val.not_nil!.visit(name, visited_ids, block)
                    self.\{{key.id}}=(%result)
                  end
                end
              \{% end %}
            \{% end %}\
            end
            \{% end %}\
            res = block.call(self)
            res.is_a?(self) ? res : self
          end

          \{%
            signatures = VALUES.map { |v| "#{v[0].id} " + (v[2] ? "= #{v[2]}" : "") }
            signature = (signatures + ["**rest"]).join(", ").id
            assignments = VALUES.map do |v|
              if v[1].id =~ /^Array/
                type = v[1].id.gsub(/Array\(/, "").gsub(/\)/, "")
                "@#{v[0].id} = #{v[0].id}.as(Array).map(&.as(#{type})).as(#{v[1].id})"
              else
                "@#{v[0].id} = #{v[0].id}.as(#{v[1].id})"
              end
            end
            %}

          def initialize(\{{signature}})
            \{{assignments.size > 0 ? assignments.join("\n").id : "".id}}
            super(**rest)
          end

        end
      end

      VALUES = [] of Tuple(Symbol, Object.class)
      VISITS = [] of Tuple(Symbol, Array(Symbol))

      macro inherited
        VALUES = [] of Tuple(Symbol, Object.class)
        VISITS = [] of Tuple(Symbol, Array(Symbol))
      end

      make_value_methods

    end
  end
end