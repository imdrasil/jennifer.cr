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
  require "../src/jennifer/adapter/mysql"
  Spec.adapter = "mysql"
{% elsif env("DB") == "sqlite3" %}
  require "../src/jennifer/adapter/sqlite3"
  Spec.adapter = "sqlite3"
{% else %}
  require "../src/jennifer/adapter/postgres"
  Spec.adapter = "postgres"
{% end %}
require "../src/jennifer"

def set_default_configuration
  Jennifer::Config.reset_config
  Jennifer::Config.configure do |conf|
    # conf.logger.level = Logger::DEBUG
    conf.logger.level = Logger::ERROR
    conf.host = "localhost"
    conf.adapter = Spec.adapter
    conf.migration_files_path = "./examples/migrations"
    conf.db = "jennifer_test"

    case Spec.adapter
    when "mysql"
      conf.user = ENV["DB_USER"]? || "root"
      conf.password = ""
    when "postgres"
      conf.user = ENV["DB_USER"]? || "developer"
      conf.password = ENV["DB_PASSWORD"]? || "1qazxsw2"
    when "sqlite3"
      conf.host = "./spec/fixtures"
      conf.db = "jennifer_test.db"
    end
  end
end

set_default_configuration
