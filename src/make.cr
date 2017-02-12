require "option_parser"
require "./jennifer"

options = {} of Symbol => String
OptionParser.parse(ARGV) do |parser|
  parser.banner = "Usage: salute [arguments"
  parser.on("db:migrate", "Run all migrations.") { options[:command] = "migrate" }
  parser.on("db:drop", "Run all migrations.") { options[:command] = "drop" }
  parser.on("db:create", "Run all migrations.") { options[:command] = "create" }
  parser.on("-g NAME", "Generate file with migrations") do |name|
    options[:command] = "generate"
    options[:name] = name
  end
end

case options[:command]
when "migrate"
  Jennifer::Migration::Runner.migrate
when "drop"
  Jennifer::Migration::Runner.drop
when "create"
  Jennifer::Migration::Runner.create
when "generate"
  Jennifer::Migration::Runner.generate(options[:name])
end
