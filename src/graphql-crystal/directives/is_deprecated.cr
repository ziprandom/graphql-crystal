module GraphQL
  module Directives
    module IsDeprecated
      macro included
        on_all_child_classes do

          alter_definition do |definition|
            # add the two fields
            # field :isDeprecated { false }
            # field :deprecationReason { nil }
          end

          before_resolve do |result|

          end

          on(:definition) do |definition|
            # field :isDeprecated { false }
            # field :deprecationReason { nil }
          end
          on(:initialization) do |schema, ast|

          end

          on(:resolve) do |resolved|
          end


        end
      end
    end
  end
end
