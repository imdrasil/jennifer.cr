require "inflector"
require "inflector/string"
require "accord"

require "ifrit/converter"
require "ifrit/core"

require "time_zone"
require "i18n"

require "./jennifer/macros"

require "./jennifer/exceptions"
require "./jennifer/adapter"
require "./jennifer/adapter/record"
require "./jennifer/config"
require "./jennifer/version"

require "./jennifer/query_builder/sql_node"
require "./jennifer/query_builder/logic_operator"
require "./jennifer/query_builder/*"

require "./jennifer/adapter/base"
require "./jennifer/relation/base"
require "./jennifer/relation/*"

require "./jennifer/model/base"

require "./jennifer/validator"

require "./jennifer/view/base"

require "./jennifer/migration/*"

module Jennifer
  {% if Jennifer.constant("AFTER_LOAD_SCRIPT") == nil %}
    AFTER_LOAD_SCRIPT = [] of String
  {% end %}

  macro after_load_hook
    {% for script in AFTER_LOAD_SCRIPT %}
      {{script.id}}
    {% end %}
  end

  class StubRelation < ::Jennifer::Relation::IRelation
    def name
      raise "stubed relation"
    end

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

    {% for method in %i(table_name model_class type set_callback condition_clause foreign_field primary_field join_query) %}
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

I18n.load_path << File.join(__DIR__, "jennifer/locale")
