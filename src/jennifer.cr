require "json"
require "yaml"
require "log"
require "uuid"

require "wordsmith"
require "ifrit/converter"
require "ifrit/core"
require "i18n"

require "./jennifer/macros"

require "./jennifer/exceptions"
require "./jennifer/adapter"
require "./jennifer/json"
require "./jennifer/adapter/record"
require "./jennifer/adapter/db_formatter"
require "./jennifer/config"

require "./jennifer/query_builder"

require "./jennifer/adapter/base"

require "./jennifer/model/base"

require "./jennifer/view/base"

require "./jennifer/migration/*"

module Jennifer
  VERSION = "0.13.0"

  {% if Jennifer.constant("AFTER_LOAD_SCRIPT") == nil %}
    # :nodoc:
    AFTER_LOAD_SCRIPT = [] of String
  {% end %}

  macro after_load_hook
    {% for script in AFTER_LOAD_SCRIPT %}
      {{script.id}}
    {% end %}
  end
end

::Jennifer.after_load_hook

# NOTE: This is needed to compile query generic class, otherwise
# `!query` at src/jennifer/adapter/base_sql_generator.cr:137:12 has no type
# exception is raised
Jennifer::QueryBuilder::ModelQuery(Jennifer::Migration::Version)
