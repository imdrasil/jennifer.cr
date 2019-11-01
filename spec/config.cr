require "./support/array_logger"
require "./support/file_system"

module Spec
  @@adapter = ""
  @@logger : ArrayLogger?
  @@file_system = FileSystem.new("./")

  def self.file_system
    @@file_system
  end

  def self.adapter
    @@adapter
  end

  def self.adapter=(v)
    @@adapter = v
  end

  def self.logger
    @@logger ||= ArrayLogger.new(STDOUT)
  end
end

Spec.file_system.tap do |fs|
  fs.watch "examples/models"
  fs.watch "examples/migrations"
end

require "../src/jennifer"
require "../src/jennifer/generators/*"
require "sam"

class Jennifer::Generators::Base
  def puts(_value); end
end

CONFIG_PATH = File.join(__DIR__, "..", "examples", "database.yml")

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
    # conf.logger = Spec.logger
    # conf.logger.level = Logger::DEBUG
    conf.logger.level = Logger::ERROR
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
  Jennifer::Config.read(CONFIG_PATH, Spec.adapter)

  Jennifer::Config.configure do |conf|
    conf.logger = Spec.logger
    conf.logger.level = Logger::DEBUG
    conf.user = ENV["DB_USER"] if ENV["DB_USER"]?
    conf.password = ENV["DB_PASSWORD"] if ENV["DB_PASSWORD"]?
    conf.verbose_migrations = false
  end
end

set_default_configuration

I18n.load_path += ["spec/fixtures/locales/**"]
I18n.default_locale = "en"
I18n.init
