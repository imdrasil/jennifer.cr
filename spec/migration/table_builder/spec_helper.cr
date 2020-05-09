require "../../spec_helper"

DEFAULT_TABLE = "test_table"

def drop_table(name = DEFAULT_TABLE)
  Jennifer::Adapter.default_adapter.exec("DROP TABLE IF EXISTS #{name}")
end
