# NOTE: WIP
module Jennifer
  module Postgres
    module Migration
      module TableBuilder
        class CreateMaterializedView < Base
          @query : QueryBuilder::Query | String

          def initialize(adapter, name, @query)
            super(adapter, name)
          end

          def process
            adapter.exec(generate_query)
          end

          def explain
            source =
              if @query.is_a?(QueryBuilder::Query)
                @query.as(QueryBuilder::Query).as_sql(adapter.sql_generator)
              else
                @query
              end
            "create_materialized_view :#{@name}, \"#{source}\""
          end

          private def generate_query
            if @query.is_a?(String)
              if Config.config.verbose_migrations
                puts "WARNING: string was used for describing source request of materialized view. " \
                     "Use QueryBuilder::Query instead"
              end
              @query.as(String)
            else
              String.build do |io|
                io <<
                  "CREATE MATERIALIZED VIEW " <<
                  @name <<
                  " AS " <<
                  adapter.sql_generator.select(@query.as(QueryBuilder::Query))
              end
            end
          end
        end
      end
    end
  end
end
