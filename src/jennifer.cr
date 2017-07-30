require "inflector"
require "inflector/string"
require "accord"
require "ifrit/converter"

require "./jennifer/exceptions"
require "./jennifer/adapter"
require "./jennifer/config"
require "./jennifer/version"

require "./jennifer/query_builder/*"
require "./jennifer/adapter/base"
require "./jennifer/migration/table_builder/*"
require "./jennifer/migration/*"
require "./jennifer/relation/base"
require "./jennifer/relation/*"
require "./jennifer/model/*"

module Jennifer
  alias Query = QueryBuilder::Query

  class StubRelation < ::Jennifer::Relation::IRelation
    def insert(a, b)
      raise "stubed relation"
    end

    def join_condition(a, b)
      raise "stubed relation"
    end

    def join_condition(a, b, &block)
      raise "stubed relation"
    end

    def query(a)
      raise "stubed relation"
    end

    def condition_clause(a)
      raise "stubed relation"
    end

    {% for method in [:table_name, :model_class, :type, :set_callback, :condition_clause, :join_query] %}
      def {{method.id}}
        raise "stubed relation"
      end
    {% end %}
  end
end

struct Time
  def_clone
end

struct JSON::Any
  def_clone
end

::Jennifer.after_load_hook
