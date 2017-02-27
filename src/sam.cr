Sam.namespace "db" do
  task "migrate" do |t, args|
    Jennifer::Migration::Runner.migrate
  end

  task "drop" do |t, args|
    Jennifer::Migration::Runner.drop
  end

  task "create" do |t, args|
    Jennifer::Migration::Runner.create
  end
end

Sam.namespace "jennifer" do
  namespace "migration" do
    task "generate" do |t, args|
      Jennifer::Migration::Runner.generate(args["name"].as(String))
    end
  end
end
