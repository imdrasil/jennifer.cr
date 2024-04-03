require "./generators/*"

Sam.namespace "db" do
  desc "Will call all pending migrations"
  task "migrate" do
    Jennifer::Migration::Runner.migrate
  end

  desc "Invoke next migration. Usage: db:step [<count>]"
  task "step" do |_, args|
    if !args.raw.empty?
      Jennifer::Migration::Runner.migrate(args.raw.last.as(String).to_i)
    else
      Jennifer::Migration::Runner.migrate(1)
    end
  end

  desc "Rollback migration. Usage: db:rollback [v=<migration_exclusive_version> | <count_to_rollback>]"
  task "rollback" do |_, args|
    if !args.raw.empty?
      Jennifer::Migration::Runner.rollback({:count => args.raw.last.as(String).to_i})
    elsif args["v"]?
      Jennifer::Migration::Runner.rollback({:to => args["v"].as(String)})
    else
      Jennifer::Migration::Runner.rollback({:count => 1})
    end
  end

  desc "Drops database"
  task "drop" do
    Jennifer::Migration::Runner.drop
  end

  desc "Creates database"
  task "create" do
    Jennifer::Migration::Runner.create
  end

  desc "Populate database with default entities."
  task "seed" do
  end

  desc "Runs db:create, db:migrate and db:seed"
  task "setup", %w(create migrate seed) do
  end

  namespace "schema" do
    desc "Loads database structure from the structure.sql file"
    task "load" do
      Jennifer::Migration::Runner.load_schema
    end
  end

  desc "Prints version of the last run migration"
  task "version" do
    version = Jennifer::Migration::Version.all.last
    if version
      puts version.not_nil!.version
    else
      puts "DB has no ran migration yet."
    end
  end
end

Sam.namespace "generate" do
  desc "Generates migration template. Usage - generate:migration <migration_name>"
  task "migration" do |_, args|
    Jennifer::Generators::Migration.new(args.raw).render
  end

  desc "Generates model and migrations template. Usage - generate:model <ModelName> <optional fields definition>"
  task "model" do |_, args|
    Jennifer::Generators::Model.new(args.raw).render
  end
end
