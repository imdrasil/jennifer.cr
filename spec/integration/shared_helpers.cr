require "../../src/jennifer"

DEFAULT_DB = "jennifer_integration_test"
DEFAULT_DOCKER_CONTAINER = "mysql"

module Spec
  @@adapter = ""

  def self.adapter
    @@adapter
  end

  def self.adapter=(v)
    @@adapter = v
  end
end

{% if env("DB") == "mysql" %}
  require "../../src/jennifer/adapter/mysql"
  Spec.adapter = "mysql"
{% elsif env("DB") == "sqlite3" %}
  require "../../src/jennifer/adapter/sqlite3"
  Spec.adapter = "sqlite3"
{% else %}
  require "../../src/jennifer/adapter/postgres"
  Spec.adapter = "postgres"
{% end %}
