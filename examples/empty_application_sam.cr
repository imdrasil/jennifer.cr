require "sam"
require "../src/jennifer/sam"
{% if env("DB") == "mysql" %}
  require "../src/jennifer/adapter/mysql"
  adapter = "mysql"
{% elsif env("DB") == "sqlite3" %}
  require "../src/jennifer/adapter/sqlite3"
  adapter = "sqlite3"
{% else %}
  require "../src/jennifer/adapter/postgres"
  adapter = "postgres"
{% end %}

Jennifer::Config.config do |conf|
  conf.db = "empty_jennifer_test"
  conf.adapter = adapter
end

Sam.help
