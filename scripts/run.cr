require "../spec/support/config"
require "../spec/support/models"
require "./migrations/*"
require "../src/jennifer/sam"

Log.setup "db",
  # :debug,
  :error,
  Log::IOBackend.new(formatter: Jennifer::Adapter::DBFormatter)

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

if SemanticVersion.parse(Sam::VERSION) < SemanticVersion.new(0, 5, 0)
  Sam.help
end
