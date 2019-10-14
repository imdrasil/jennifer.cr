require "../../src/jennifer"

DEFAULT_DB = "jennifer_integration_test"
DEFAULT_DOCKER_CONTAINER = "mysqld"

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
{% else %}
  require "../../src/jennifer/adapter/postgres"
  Spec.adapter = "postgres"
{% end %}
