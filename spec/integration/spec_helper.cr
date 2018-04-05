require "../../src/jennifer"

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

module Spec
  # :nodoc:
  struct CommandSucceedExpectation
    def match(tuple)
      tuple[0] == 0
    end

    def failure_message(tuple)
      "Expected command to return status 0, got #{tuple[0]}.\nError message:\n#{tuple[1]}"
    end

    def negative_failure_message(tuple)
      "Expected command to return non 0 status, got #{tuple[0]}.\nError message:\n#{tuple[1]}"
    end
  end

  module Expectations
    def succeed
      CommandSucceedExpectation.new
    end
  end
end
