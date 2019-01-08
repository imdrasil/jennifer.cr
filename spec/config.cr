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
require "sam"
require "../src/jennifer/generators/*"

class Jennifer::Generators::Base
  def puts(_value); end
end

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
  {% elsif env("DB") == "postgres" %}
    require "../src/jennifer/adapter/mysql"
  {% end %}
{% end %}

def set_default_configuration
  Jennifer::Config.reset_config
  Jennifer::Config.read(File.join(__DIR__, "..", "examples", "database.yml"), Spec.adapter)

  Jennifer::Config.configure do |conf|
    conf.logger = Spec.logger
    conf.logger.level = Logger::DEBUG
    conf.user = ENV["DB_USER"] if ENV["DB_USER"]?
    conf.password = ENV["DB_PASSWORD"] if ENV["DB_PASSWORD"]?
  end
end

set_default_configuration

I18n.load_path += ["spec/fixtures/locales/**"]
I18n.default_locale = "en"
I18n.init
