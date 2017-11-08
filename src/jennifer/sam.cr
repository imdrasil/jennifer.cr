Sam.namespace "db" do
  desc "Will call all pending migrations"
  task "migrate" do |t, args|
    Jennifer::Migration::Runner.migrate(config_key(args), 1)
  end

  desc "Invoke next migration. Usage: db:step [<count>]"
  task "step" do |t, args|
    if !args.raw.empty?
      Jennifer::Migration::Runner.migrate(config_key(args), args.raw.last.as(String).to_i)
    else
      Jennifer::Migration::Runner.migrate(config_key(args), 1)
    end
  end

  desc "Rollback migration. Usage: db:rollback [v=<migration_exclusive_version> | <count_to_rollback>]"
  task "rollback" do |t, args|
    options = {:count => 1}
    if !args.raw.empty?
      options = {:count => args.raw.last.as(String).to_i}
    elsif args["v"]?
      options = {:to => args["v"].as(String)}
    end
    Jennifer::Migration::Runner.rollback(config_key(args), options)
  end

  desc "Drops database"
  task "drop" do |t, args|
    puts Jennifer::Migration::Runner.drop(config_key(args))
  end

  desc "Creates database"
  task "create" do |t, args|
    puts Jennifer::Migration::Runner.create(config_key(args))
  end

  desc "Runs db:create and db:migrate"
  task "setup", ["create", "migrate"] do
  end

  namespace "schema" do
    desc "Loads database structure from structure.sql"
    task "load" do |t, args|
      Jennifer::Migration::Runner.load_schema(config_key(args))
    end
  end

  desc "Prints version of last migration run"
  task "version" do
    version = Jennifer::Migration::Version.all.last
    if version
      puts version.not_nil!.version
    else
      puts "DB has no ran migration yet."
    end
  end
end

private def config_key(args)
  return args["config"].to_s if args["config"]?
  "default"
end

Sam.namespace "generate" do
  desc "Generates migration template. Usage generate:migration <migration_name>"
  task "migration" do |t, args|
    Jennifer::Migration::Runner.generate(args[0].as(String))
  end
end
