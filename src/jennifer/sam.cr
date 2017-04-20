Sam.namespace "db" do
  task "migrate" do |t, args|
    Jennifer::Migration::Runner.migrate
  end

  task "rollback" do |t, args|
    if !args.raw.empty?
      Jennifer::Migration::Runner.rollback({:count => args.raw.last.as(String).to_i})
    elsif args["v"]?
      Jennifer::Migration::Runner.rollback({:to => args["v"].as(String)})
    else
      Jennifer::Migration::Runner.rollback({:count => 1})
    end
  end

  task "drop" do |t, args|
    puts Jennifer::Migration::Runner.drop
  end

  task "create" do |t, args|
    puts Jennifer::Migration::Runner.create
  end

  task "setup", ["create", "migrate"] do
  end

  task "version" do
    puts Jennifer::Migration::Version.all.to_a[-1].version
  end
end

Sam.namespace "generate" do
  task "migration" do |t, args|
    Jennifer::Migration::Runner.generate(args[0].as(String))
  end
end
