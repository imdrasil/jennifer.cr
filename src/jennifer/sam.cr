Sam.namespace "db" do
  desc "Will call all pending migrations"
  task "migrate" do |t, args|
    Jennifer::Migration::Runner.migrate
  end

  desc "Invoke next migration. Usage: db:step [<count>]"
  task "step" do |t, args|
    if !args.raw.empty?
      Jennifer::Migration::Runner.migrate(args.raw.last.as(String).to_i)
    else
      Jennifer::Migration::Runner.migrate(1)
    end
  end

  desc "Rollback migration. Usage: db:rollback [v=<migration_exclusive_version> | <count_to_rollback>]"
  task "rollback" do |t, args|
    if !args.raw.empty?
      Jennifer::Migration::Runner.rollback({:count => args.raw.last.as(String).to_i})
    elsif args["v"]?
      Jennifer::Migration::Runner.rollback({:to => args["v"].as(String)})
    else
      Jennifer::Migration::Runner.rollback({:count => 1})
    end
  end

  desc "Drops database"
  task "drop" do |t, args|
    puts Jennifer::Migration::Runner.drop
  end

  desc "Creates database"
  task "create" do |t, args|
    puts Jennifer::Migration::Runner.create
  end

  desc "Runs db:create and db:migrate"
  task "setup", ["create", "migrate"] do
  end

  namespace "schema" do
    desc "Loads database structure from structure.sql"
    task "load" do
      Jennifer::Migration::Runner.load_schema
    end
  end

  desc "Prints version of last runned migration"
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
  desc "Generates migration template. Usage generate:migration <migration_name>"
  task "migration" do |t, args|
    Jennifer::Migration::Runner.generate(args[0].as(String))
  end
end
