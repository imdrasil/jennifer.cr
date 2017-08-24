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

Spec.before_each do
  Jennifer::Adapter.adapter.begin_transaction
end

Spec.after_each do
  Jennifer::Adapter.adapter.rollback_transaction
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
