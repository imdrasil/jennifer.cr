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
require "./models.cr"
require "./factories.cr"

# This was added to track exact count of hitting DB
abstract class DB::Connection
  def scalar(query, *args)
    Jennifer::Adapter.adapter_class.log_query(query)
    build(query).scalar(*args)
  end

  def query(query, *args)
    Jennifer::Adapter.adapter_class.log_query(query)
    rs = query(query, *args)
    yield rs ensure rs.close
  end

  def exec(query, *args)
    Jennifer::Adapter.adapter_class.log_query(query)
    build(query).exec(*args)
  end
end

abstract class Jennifer::Adapter::Base
  @@execution_counter = 0
  @@queries = [] of String

  def self.exec_count
    @@execution_counter
  end

  def self.log_query(query)
    @@execution_counter += 1
    @@queries << query
  end

  def self.query_log
    @@queries
  end

  def self.remove_queries
    @@queries.clear
  end
end

# Callbaks =======================

Spec.before_each do
  Jennifer::Adapter.adapter.begin_transaction
end

Spec.after_each do
  Jennifer::Adapter.adapter.class.remove_queries
  Jennifer::Adapter.adapter.rollback_transaction
end

# Helper methods ================

def clean_db
  Jennifer::Adapter.adapter.class.remove_queries
  postgres_only do
    Jennifer::Adapter.adapter.refresh_materialized_view(FemaleContact.table_name)
  end
  Jennifer::Model::Base.models.select { |t| t.has_table? }.each(&.all.delete)
end

macro void_transaction
  Jennifer::Adapter.adapter.rollback_transaction
  {{yield}}
  clean_db
  Jennifer::Adapter.adapter.begin_transaction
end

def match_array(expect, target)
  (expect - target).size.should eq(0)
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

def select_clause(query)
  String.build { |s| ::Jennifer::Adapter::SqlGenerator.select_clause(s, query) }
end

def select_query(query)
  ::Jennifer::Adapter::SqlGenerator.select(query)
end

def db_array(*element)
  element.to_a.map { |e| e.as(Jennifer::DBAny) }
end

def query_count
  Jennifer::Adapter.adapter_class.exec_count
end

def query_log
  Jennifer::Adapter.adapter_class.query_log
end

def read_to_end(rs)
  rs.each do
    rs.columns.size.times do
      rs.read
    end
  end
end
