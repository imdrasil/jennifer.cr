require "logger"

class ArrayLogger < Logger
  property silent : Bool
  getter container = [] of {sev: String, msg: String}

  def initialize(@io : IO?, @silent = true)
    @level = Severity::INFO
    @formatter = DEFAULT_FORMATTER
    @progname = ""
    @closed = false
    @mutex = Mutex.new
    @formatter = Formatter.new do |_, _, _, msg, io|
      io << msg
    end
  end

  def clear
    @container.clear
  end

  private def write(severity, datetime, progname, message)
    progname_to_s = progname.to_s
    message_to_s = message.to_s
    @mutex.synchronize do
      new_message = String.build do |io|
        formatter.call(severity, datetime, progname_to_s, message_to_s, io)
      end
      @container << {sev: severity.to_s, msg: new_message}
    end
  end
end

module Spec
  @@adapter = ""
  @@logger : ArrayLogger?

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

require "../src/jennifer"

{% if env("DB") == "mysql" %}
  require "../src/jennifer/adapter/mysql"
  Spec.adapter = "mysql"
{% elsif env("DB") == "sqlite3" %}
  require "../src/jennifer/adapter/sqlite3"
  Spec.adapter = "sqlite3"
{% else %}
  require "../src/jennifer/adapter/postgres"
  Spec.adapter = "postgres"

  {% if env("LEGACY_INSERT") == "1" %}
    require "../src/jennifer/adapter/postgres/legacy_insert"
  {% end %}
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
  Jennifer::Config.configure do |conf|
    conf.logger = Spec.logger
    conf.logger.level = Logger::DEBUG
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
    # when "sqlite3"
    #   conf.host = "./spec/fixtures"
    #   conf.db = "jennifer_test.db"
    end
  end
end

set_default_configuration

I18n.load_path += ["spec/fixtures/locales/**"]
I18n.default_locale = "en"
I18n.init
