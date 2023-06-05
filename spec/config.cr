require "./support/file_system"

module Spec
  class_property adapter = ""
  class_getter file_system = FileSystem.new("./")
  class_getter logger_backend = Log::MemoryBackend.new
  class_getter logger = Log.for("db", Log::Severity::Debug)
end

Spec.file_system.tap do |fs|
  fs.watch "scripts/models"
  fs.watch "scripts/migrations"
end

require "../src/jennifer"
require "../src/jennifer/generators/*"
require "sam"

class Jennifer::Generators::Base
  def puts(_value); end
end

CONFIG_PATH = File.join(__DIR__, "..", "scripts", "database.yml")

{% if env("DB") == "mysql" %}
  require "../src/jennifer/adapter/mysql"
  Spec.adapter = "mysql"
{% else %}
  require "../src/jennifer/adapter/postgres"
  Spec.adapter = "postgres"
{% end %}

{% if env("PAIR") == "1" %}
  # Additionally loads opposite adapter
  {% if env("DB") == "mysql" %}
    require "../src/jennifer/adapter/postgres"
    EXTRA_ADAPTER_NAME = "postgres"
  {% else %}
    require "../src/jennifer/adapter/mysql"
    EXTRA_ADAPTER_NAME = "mysql"
  {% end %}

  EXTRA_SETTINGS = Jennifer::Config.new.read(CONFIG_PATH, EXTRA_ADAPTER_NAME).tap do |conf|
    conf.logger = Spec.logger
    conf.user = ENV["PAIR_DB_USER"] if ENV["PAIR_DB_USER"]?
    conf.password = ENV["PAIR_DB_PASSWORD"] if ENV["PAIR_DB_PASSWORD"]?
    conf.verbose_migrations = false
    conf.db = "jennifer_test_pair"
  end

  PAIR_ADAPTER =
    if EXTRA_ADAPTER_NAME == "mysql"
      Jennifer::Mysql::Adapter.new(EXTRA_SETTINGS)
    else
      Jennifer::Postgres::Adapter.new(EXTRA_SETTINGS)
    end
{% end %}

def set_default_configuration
  Jennifer::Config.reset_config

  Jennifer::Config.configure do |conf|
    conf.read(File.join(__DIR__, "../scripts/database.yml"), Spec.adapter)
    conf.logger = Spec.logger
    # conf.logger.level = :debug
    conf.user = ENV["DB_USER"] if ENV["DB_USER"]?
    conf.password = ENV["DB_PASSWORD"] if ENV["DB_PASSWORD"]?
    conf.verbose_migrations = false
    conf.local_time_zone_name = "Europe/Kiev"
    conf.pool_size = (ENV["DB_CONNECTION_POOL"]? || 1).to_i
  end

  Log.setup "db", :debug, Spec.logger_backend
  # Log.setup "db", :debug, Log::IOBackend.new(formatter: Jennifer::DBFormat)
end

set_default_configuration

I18n.load_path += ["spec/fixtures/locales/**"]
I18n.default_locale = "en"
I18n.init
