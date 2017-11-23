# NOTE: WIP
module Jennifer
  module Migration
    module TableBuilder
      class CreateMaterializedView < Base
        @query : QueryBuilder::Query | String

        def initialize(name, @query)
          super(name)
        end

        def process
          buff = generate_query
          adapter.exec buff
        end

        private def generate_query
          if @query.is_a?(String)
            puts "String was used for describing source request of materialized  view. Use QueryBuilder::Query instead"
            @query.as(String)
          else
            String.build do |s|
              s <<
                "CREATE MATERIALIZED VIEW " <<
                @name <<
                " AS " <<
                Adapter::SqlGenerator.select(@query.as(QueryBuilder::Query))
            end
          end
        end
      end
    end
  end
end
