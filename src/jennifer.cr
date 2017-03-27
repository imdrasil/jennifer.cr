require "./jennifer/exceptions"
require "json"
require "./jennifer/*"

# require "./jennifer/adapter/*"
require "./jennifer/adapter/base"
require "./jennifer/migration/table_builder/*"
require "./jennifer/migration/*"
require "./jennifer/model/*"
require "./jennifer/query_builder/*"

module Jennifer
  class StubRelation < ::Jennifer::Model::IRelation
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
