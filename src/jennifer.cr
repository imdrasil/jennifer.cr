require "json"
require "inflector"
require "inflector/string"
require "accord"

require "./jennifer/exceptions"
require "./jennifer/*"

require "./jennifer/adapter/base"
require "./jennifer/migration/table_builder/*"
require "./jennifer/migration/*"
require "./jennifer/query_builder/*"
require "./jennifer/model/*"

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
