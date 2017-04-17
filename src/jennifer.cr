require "json"
require "inflector"
require "inflector/string"
require "accord"

require "./jennifer/exceptions"
require "./jennifer/adapter"
require "./jennifer/config"
require "./jennifer/exceptions"
require "./jennifer/support"
require "./jennifer/version"

require "./jennifer/query_builder/*"
require "./jennifer/adapter/base"
require "./jennifer/migration/table_builder/*"
require "./jennifer/migration/*"
require "./jennifer/relation/base"
require "./jennifer/relation/*"
require "./jennifer/model/*"

module Jennifer
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

    def table_name
      raise "stubed relation"
    end

    def model_class
      raise "stubed relation"
    end

    def type
      raise "stubed relation"
    end

    def set_callback
      raise "stubed relation"
    end

    def condition_clause
      raise "stubed relation"
    end

    def condition_clause(a)
      raise "stubed relation"
    end

    def join_query
      raise "not_implemented"
    end
  end
end

::Jennifer.after_load_hook
