require "../spec/config"
require "../spec/models"
require "./migrations/*"
require "../src/jennifer/sam"

# ameba:disable Lint/UnusedArgument
Jennifer::Config.configure do |conf|
  # conf.logger.level = :error
end

Log.setup "db", :debug, Log::IOBackend.new(formatter: Jennifer::Adapter::DBFormatter)

Sam.namespace "script" do
  task "drop_models" do
    Jennifer::Model::Base.models.select(&.has_table?).each(&.all.delete)
  end
end

{% if env("PAIR") == "1" %}
  Sam.namespace "db" do
    task "create" do
      Jennifer::Migration::Runner.create
      Jennifer::Migration::Runner.create(PAIR_ADAPTER)
      Jennifer::Migration::TableBuilder::CreateTable.new(PAIR_ADAPTER, "addresses").tap do |t|
        t.integer :id, {:primary => true, :auto_increment => true}
        t.json :details
        t.string :street
        t.integer :number

        t.index :street, :unique
      end.process
    end

    task "drop" do
      Jennifer::Migration::Runner.drop
      Jennifer::Migration::Runner.drop(PAIR_ADAPTER)
    end
  end
{% end %}

Sam.help
