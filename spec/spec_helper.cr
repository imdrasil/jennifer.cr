macro postgres_only
  {% if env("DB") == "postgres" || env("DB") == nil %}
    {{yield}}
  {% end %}
end

macro mysql_only
  {% if env("DB") == "mysql" %}
    {{yield}}
  {% end %}
end

macro pair_only
  {% if env("PAIR") == "1" %}
    {{yield}}
  {% end %}
end

require "spec"
require "factory"
require "./support/*"

require "../scripts/migrations/20170119011451314_create_contacts"
require "../scripts/migrations/20180909200027509_create_notes"

class Jennifer::Adapter::ICommandShell
  class_property? stub = false
end

class Jennifer::Adapter::Bash < Jennifer::Adapter::ICommandShell
  private def invoke(string, options)
    if Jennifer::Adapter::ICommandShell.stub?
      {result: 0, output: [string, options]}
    else
      super
    end
  end
end

class Jennifer::Adapter::Docker < Jennifer::Adapter::ICommandShell
  private def invoke(string, options)
    if Jennifer::Adapter::ICommandShell.stub?
      {result: 0, output: [string, options]}
    else
      super
    end
  end
end

# Callbacks =======================

Spec.before_each do
  set_default_configuration # NOTE: this allows to test configs changes in tests
  Spec.logger_backend.entries.clear
  Jennifer::Adapter.default_adapter.begin_transaction # NOTE: wraps everything in a transaction
  pair_only { PAIR_ADAPTER.begin_transaction }
end

Spec.after_each do
  Jennifer::Adapter.default_adapter.rollback_transaction
  pair_only { PAIR_ADAPTER.rollback_transaction }
  Spec.file_system.clean
  # puts Spec.logger_backend.entries.map(&.data.first).flatten
  Jennifer::Adapter::ICommandShell.stub = false
end

# Helper methods ================

UTC    = Time::Location.load("UTC")
BERLIN = Time::Location.load("Europe/Berlin")

macro validated_by_record(field, value, opts = {} of Void => Void)
  begin
    allow_blank = {{opts[:allow_blank]}} || true
    __record__ =
      {% if !opts[:record] %}
        Factory.build_contact
      {% else %}
        {{opts[:record]}}
      {% end %}
    described_class.instance.validate(
      __record__,
      field: {{field}},
      value: {{value}},
      allow_blank: allow_blank,
      {% for key, value in opts %}
        {% if key != :allow_blank && key != :record %}
          {{key.id}}: {{value}},
        {% end %}
      {% end %}
    )
    __record__
  end
end

def clean_db
  postgres_only do
    Jennifer::Adapter.default_adapter
      .as(Jennifer::Postgres::Adapter)
      .refresh_materialized_view(FemaleContact.table_name)
  end
  (Jennifer::Model::Base.models - [Jennifer::Migration::Version]).select(&.has_table?).each(&.all.delete)
end

# Ends current transaction, yields to the block, clear and starts next one
macro void_transaction
  begin
    Jennifer::Adapter.default_adapter.rollback_transaction
    Spec.logger_backend.entries.clear
    {{yield}}
  ensure
    clean_db
    Jennifer::Adapter.default_adapter.begin_transaction
  end
end

def grouping(exp)
  Jennifer::QueryBuilder::Grouping.new(exp)
end

def select_query(query)
  ::Jennifer::Adapter.default_adapter.sql_generator.select(query)
end

def db_array(*element)
  element.to_a.map { |e| e.as(Jennifer::DBAny) }
end

def query_count
  Spec.logger_backend.entries.size
end

def query_log
  offset = ENV["PAIR"]? == "1" ? 2 : 1
  Spec.logger_backend.entries[offset..-1].map(&.data)
end

def read_to_end(rs)
  rs.each do
    rs.columns.size.times do
      rs.read
    end
  end
end

def local_time_zone
  Jennifer::Config.local_time_zone
end

def with_time_zone(zone_name : String, &)
  old_zone = Jennifer::Config.local_time_zone_name
  begin
    Jennifer::Config.local_time_zone_name = zone_name
    yield
  ensure
    Jennifer::Config.local_time_zone_name = old_zone
  end
end

def db_specific(mysql, postgres)
  case Spec.adapter
  when "postgres"
    postgres.call
  when "mysql"
    mysql.call
  else
    raise "Unknown adapter type"
  end
end

# SQL query clauses =============

def sb(&)
  String.build { |io| yield io }
end

def select_clause(query)
  sb { |io| sql_generator.select_clause(io, query) }
end

def join_clause(query)
  sb { |io| sql_generator.join_clause(io, query) }
end

private def sql_generator
  ::Jennifer::Adapter.default_adapter.sql_generator
end

def stub_command_shell
  Jennifer::Adapter::ICommandShell.stub = true
end
