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

require "spec"
require "factory"
require "./config"
require "./models"
require "./factories"
require "./support/*"

require "../examples/migrations/20170119011451314_create_contacts"
require "../examples/migrations/20180909200027509_create_notes"

# Callbacks =======================

Spec.before_each do
  Jennifer::Adapter.adapter.begin_transaction
  set_default_configuration
  Spec.logger.clear
end

Spec.after_each do
  Jennifer::Adapter.adapter.rollback_transaction
  Spec.file_system.clean
end

# Helper methods ================

UTC = Time::Location.load("UTC")
BERLIN = Time::Location.load("Europe/Berlin")

macro validated_by_record(type, value, field = :age, allow_blank = true)
  Factory.build_contact.tap do |record|
    described_class.instance.validate(record, {{field}}, {{value}}, {{allow_blank}}, **{{type}})
  end
end

def clean_db
  postgres_only do
    Jennifer::Adapter.adapter.as(Jennifer::Postgres::Adapter).refresh_materialized_view(FemaleContact.table_name)
  end
  (Jennifer::Model::Base.models - [Jennifer::Migration::Version]).select { |t| t.has_table? }.each(&.all.delete)
end

# Ends current transaction, yields to the block, clear and starts next one
macro void_transaction
  begin
    Jennifer::Adapter.adapter.rollback_transaction
    Spec.logger.clear
    {{yield}}
  ensure
    clean_db
    Jennifer::Adapter.adapter.begin_transaction
  end
end

def grouping(exp)
  Jennifer::QueryBuilder::Grouping.new(exp)
end

def select_query(query)
  ::Jennifer::Adapter.adapter.sql_generator.select(query)
end

def db_array(*element)
  element.to_a.map { |e| e.as(Jennifer::DBAny) }
end

def query_count
  Spec.logger.container.size
end

def query_log
  Spec.logger.container.map { |e| e[:msg] }
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

def with_time_zone(zone_name : String)
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

private def sql_generator
  ::Jennifer::Adapter.adapter.sql_generator
end

def sb
  String.build { |io| yield io }
end

def select_clause(query)
  sb { |s| sql_generator.select_clause(s, query) }
end

def join_clause(query)
  sb { |io| sql_generator.join_clause(io, query) }
end
