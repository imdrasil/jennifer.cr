require "../../src/jennifer"

DEFAULT_DB                  = "jennifer_integration_test"
DB_CONNECTION_SETTINGS_PATH = File.join(__DIR__, "../../scripts/database.yml")
POSTGRES_DB                 = "postgres"
MYSQL_DB                    = "mysql"

module Spec
  class_property adapter = ""

  def self.config_jennifer
    config_jennifer { }
  end

  def self.config_jennifer(&)
    Jennifer::Config.reset_config

    Jennifer::Config.configure do |conf|
      conf.read(DB_CONNECTION_SETTINGS_PATH, Spec.adapter)
      conf.user = db_user
      conf.password = db_password
      conf.db = db
      conf.verbose_migrations = false
      yield conf
    end
  end

  def self.settings
    YAML.parse(File.read(DB_CONNECTION_SETTINGS_PATH))[Spec.adapter]
  end

  def self.db_user
    ENV["DB_USER"]? || Spec.settings["user"]?.try(&.as_s) ||
      case Spec.adapter
      when POSTGRES_DB
        "developer"
      when MYSQL_DB
        "root"
      else
        unknown_adapter!
      end
  end

  def self.db_password
    ENV["DB_PASSWORD"]? || Spec.settings["password"]?.try(&.as_s) ||
      case Spec.adapter
      when POSTGRES_DB
        "1qazxs2"
      when MYSQL_DB
        ""
      else
        unknown_adapter!
      end
  end

  def self.db
    DEFAULT_DB
  end

  def self.unknown_adapter!
    raise "Unknown adapter"
  end
end

{% if env("DB") == "mysql" %}
  require "../../src/jennifer/adapter/mysql"
  Spec.adapter = "mysql"
{% else %}
  require "../../src/jennifer/adapter/postgres"
  Spec.adapter = "postgres"
{% end %}
