require "./file_system"

module Spec
  class_property adapter = ""
  class_getter file_system = FileSystem.new("./")
  class_getter logger_backend = Log::MemoryBackend.new

  def self.logger
    Jennifer::Config.instance.logger
  end
end

Spec.file_system.tap do |file_system|
  file_system.watch "scripts/models"
  file_system.watch "scripts/migrations"
end

require "../../src/jennifer"
require "../../src/jennifer/generators/*"
require "../../src/jennifer/adapter/db_colorized_formatter"
require "sam"

class Jennifer::Generators::Base
  def puts(_value); end
end

CONFIG_PATH = File.join(__DIR__, "..", "scripts", "database.yml")

{% if env("DB") == "mysql" %}
  require "../../src/jennifer/adapter/mysql"
  Spec.adapter = "mysql"
{% else %}
  require "../../src/jennifer/adapter/postgres"
  Spec.adapter = "postgres"
{% end %}

{% if env("PAIR") == "1" %}
  # Additionally loads opposite adapter
  {% if env("DB") == "mysql" %}
    require "../../src/jennifer/adapter/postgres"
    EXTRA_ADAPTER_NAME = "postgres"
  {% else %}
    require "../../src/jennifer/adapter/mysql"
    EXTRA_ADAPTER_NAME = "mysql"
  {% end %}

  EXTRA_SETTINGS = Jennifer::Config.new.read(CONFIG_PATH, EXTRA_ADAPTER_NAME).tap do |conf|
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

Jennifer::Adapter::DBColorizedFormatter.colors = {
  source:       Colorize::ColorRGB.new(17, 120, 100),
  args:         :yellow,
  query_insert: :green,
  query_delete: Colorize::ColorRGB.new(236, 88, 0),
  query_update: :red,
  query_select: :cyan,
  query_other:  :magenta,
}

def set_default_configuration
  Jennifer::Config.reset_config

  Jennifer::Config.configure do |conf|
    conf.read(File.join(__DIR__, "../../scripts/database.yml"), Spec.adapter)
    conf.user = ENV["DB_USER"] if ENV["DB_USER"]?
    conf.password = ENV["DB_PASSWORD"] if ENV["DB_PASSWORD"]?
    conf.verbose_migrations = false
    conf.local_time_zone_name = "Europe/Kiev"
    conf.pool_size = (ENV["DB_CONNECTION_POOL"]? || 1).to_i
  end

  Log.setup do |conf|
    conf.bind "db", :debug, Spec.logger_backend
    conf.bind "db",
      ENV["STD_LOGS"]? == "1" ? Log::Severity::Debug : Log::Severity::None,
      Log::IOBackend.new(formatter: Jennifer::Adapter::DBColorizedFormatter)
  end
end

set_default_configuration

I18n.load_path += ["spec/fixtures/locales/**"]
I18n.default_locale = "en"
I18n.init
