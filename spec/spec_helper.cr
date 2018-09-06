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

# Callbacks =======================

Spec.before_each do
  Jennifer::Adapter.adapter.begin_transaction
  set_default_configuration
end

Spec.after_each do
  Jennifer::Adapter.adapter.rollback_transaction
  Spec.logger.clear
end

# Helper methods ================

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

def select_clause(query)
  String.build { |s| ::Jennifer::Adapter.adapter.sql_generator.select_clause(s, query) }
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

def sb
  String.build { |io| yield io }
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

# Matchers ======================

def match_array(expect, target)
  (expect - target).size.should eq(0)
  (target - expect).size.should eq(0)
rescue e
  puts "Actual array: #{expect}"
  puts "Expected: #{target}"
  raise e
end

def match_each(source, target)
  source.size.should eq(target.size)
  source.each do |e|
    target.includes?(e).should be_true
  end
rescue e
  puts "Actual array: #{source}"
  puts "Expected: #{target}"
  raise e
end

macro match_fields(object, fields)
  {% for field, value in fields %}
    {{object}}.{{field.id}}.should eq({{value}})
  {% end %}
end

macro match_fields(object, **fields)
  {% for field, value in fields %}
    {{object}}.{{field.id}}.should eq({{value}})
  {% end %}
end
