Sam.namespace "db" do
  task "migrate" do |t, args|
    Jennifer::Migration::Runner.migrate
  end

  task "drop" do |t, args|
    puts "asd"
    puts Jennifer::Migration::Runner.drop
  end

  task "create" do |t, args|
    puts Jennifer::Migration::Runner.create
  end

  task "version" do
    puts Jennifer::Migration::Version.all.to_a[-1].version
  end
end

Sam.namespace "jennifer" do
  namespace "migration" do
    task "generate" do |t, args|
      Jennifer::Migration::Runner.generate(args["name"].as(String))
    end
  end
end
