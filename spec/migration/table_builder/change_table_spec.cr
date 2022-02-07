require "./spec_helper"

def change_table_expr(table = DEFAULT_TABLE)
  Jennifer::Migration::TableBuilder::ChangeTable.new(Jennifer::Adapter.default_adapter, table)
end

describe Jennifer::Migration::TableBuilder::ChangeTable do
  describe "#rename_table" do
    it do
      table = change_table_expr
      table.rename_table("renamed_table")
      table.new_table_name.should eq("renamed_table")
    end

    postgres_only do
      it do
        table = change_table_expr(:cities)
        table.rename_table(:towns)
        table.process
        Jennifer::Adapter.default_adapter.table_exists?(:towns).should be_true
      end
    end
  end

  describe "#change_column" do
    it do
      table = change_table_expr
      table.change_column(:name, :integer)
      table.changed_columns["name"].should eq({:new_name => :name, :type => :integer})
    end

    postgres_only do
      it do
        table = change_table_expr(:cities)
        table.change_column(:name, :text)
        table.process
      end
    end

    context "with specified type" do
      it do
        table = change_table_expr
        table.change_column(:name, :integer, {:new_name => :new_name, :null => false})
        table.changed_columns["name"].should eq({:new_name => :new_name, :type => :integer, :null => false})
      end
    end

    context "with specified sql type in options" do
      it do
        table = change_table_expr
        table.change_column(:name, options: {:new_name => :new_name, :null => false, :sql_type => "SOME_TYPE"})
        table.changed_columns["name"]
          .should eq({:new_name => :new_name, :type => nil, :null => false, :sql_type => "SOME_TYPE"})
      end
    end

    context "with specified type only in options" do
      it do
        table = change_table_expr
        expect_raises(ArgumentError) do
          table.change_column(:name, options: {:new_name => :new_name, :null => false, :type => :integer})
        end
      end
    end
  end

  describe "#add_column" do
    it do
      table = change_table_expr
      table.add_column(:name, :integer)
      table.@new_columns["name"].should eq({:type => :integer})
    end

    postgres_only do
      it do
        table = change_table_expr(:cities)
        table.add_column(:text, :string)
        table.process
        Jennifer::Adapter.default_adapter.column_exists?(:cities, :text).should be_true
      end
    end

    context "with specified type" do
      it do
        table = change_table_expr
        table.add_column(:name, :integer, {:null => false})
        table.@new_columns["name"].should eq({:type => :integer, :null => false})
      end
    end

    context "with specified sql type in options" do
      it do
        table = change_table_expr
        table.add_column(:name, options: {:null => false, :sql_type => "SOME_TYPE"})
        table.@new_columns["name"].should eq({:type => nil, :null => false, :sql_type => "SOME_TYPE"})
      end
    end

    context "with specified type only in options" do
      it do
        table = change_table_expr
        expect_raises(ArgumentError) do
          table.add_column(:name, options: {:null => false, :type => :integer})
        end
      end
    end
  end

  describe "#drop_column" do
    it do
      table = change_table_expr
      table.drop_column("uuid")
      table.drop_columns.should eq(["uuid"])
    end

    postgres_only do
      it do
        table = change_table_expr(:cities)
        table.drop_column(:name)
        table.process
        Jennifer::Adapter.default_adapter.column_exists?(:cities, :name).should be_false
      end
    end
  end

  describe "#add_reference" do
    it "creates column based on given field" do
      table = change_table_expr
      table.add_reference(:user)
      table.@new_columns["user_id"].should eq({:type => :bigint, :null => true})

      command = table.@commands[0].as(Jennifer::Migration::TableBuilder::CreateForeignKey)
      command.from_table.should eq(DEFAULT_TABLE)
      command.to_table.should eq("users")
      command.column.should eq("user_id")
      command.primary_key.should eq("id")
      command.name.starts_with?("fk_cr_").should be_true
    end

    postgres_only do
      it do
        table = change_table_expr(:cities)
        table.add_reference(:user)
        table.process
        Jennifer::Adapter.default_adapter.column_exists?(:cities, :user_id).should be_true
        Jennifer::Adapter.default_adapter.foreign_key_exists?(:cities, :user).should be_true
      end
    end

    describe "polymorphic" do
      it "adds foreign and polymorphic columns" do
        table = change_table_expr
        table.add_reference(:user, options: {:polymorphic => true})
        table.@new_columns["user_id"].should eq({:polymorphic => true, :type => :bigint, :null => true})
        table.@new_columns["user_type"].should eq({:type => :string, :null => true})
        table.@commands.should be_empty
      end
    end
  end

  describe "#drop_reference" do
    it "generates correct command" do
      table = change_table_expr
      table.drop_reference(:user)
      table.drop_columns.should be_empty

      command = table.@commands[0].as(Jennifer::Migration::TableBuilder::DropReference)
      command = command.@commands[0].as(Jennifer::Migration::TableBuilder::DropForeignKey)

      command.from_table.should eq(DEFAULT_TABLE)
      command.to_table.should eq("users")
      command.name.starts_with?("fk_cr_").should be_true
    end

    postgres_only do
      it do
        table = change_table_expr(:passports)
        table.drop_reference(:contact)
        table.process
        table.adapter.foreign_key_exists?(:passports, :contact).should be_false
      end
    end

    describe "polymorphic" do
      it "generates correct command" do
        table = change_table_expr
        table.drop_reference(:user, options: {:polymorphic => true})
        table.drop_columns.should eq(["user_type", "user_id"])
        table.@commands.should be_empty
      end
    end
  end

  describe "#add_timestamps" do
    it "creates updated_at and created_at columns" do
      table = change_table_expr
      table.add_timestamps
      table.@new_columns["created_at"].should eq({:type => :timestamp, :null => false})
      table.@new_columns["updated_at"].should eq({:type => :timestamp, :null => false})
    end

    postgres_only do
      it do
        table = change_table_expr(:cities)
        table.add_timestamps
        table.process
        Jennifer::Adapter.default_adapter.column_exists?(:cities, :created_at).should be_true
        Jennifer::Adapter.default_adapter.column_exists?(:cities, :updated_at).should be_true
      end
    end
  end

  describe "#add_index" do
    postgres_only do
      it do
        table = change_table_expr(:cities)
        table.add_index(:name)
        table.process
        Jennifer::Adapter.default_adapter.index_exists?(:cities, [:name]).should be_true
      end
    end

    context "with named arguments" do
      it do
        table = change_table_expr
        table.add_index(name: "nodes_uuid_index", field: :uuid, type: :uniq, order: :asc)
        command = table.@commands[0].as(Jennifer::Migration::TableBuilder::CreateIndex)
        command.fields.should eq([:uuid])
        command.type.should eq(:uniq)
        command.lengths.empty?.should be_true
        command.orders[:uuid].should eq(:asc)
      end
    end

    context "with plain arguments and specified length" do
      it do
        table = change_table_expr
        table.add_index(:uuid, :uniq, length: 10, order: :asc)
        command = table.@commands[0].as(Jennifer::Migration::TableBuilder::CreateIndex)
        command.fields.should eq([:uuid])
        command.type.should eq(:uniq)
        command.lengths[:uuid].should eq(10)
        command.orders[:uuid].should eq(:asc)
      end
    end

    context "with multiple fields" do
      it do
        table = change_table_expr
        table.add_index([:uuid, :name], :uniq, orders: {:uuid => :asc, :name => :desc})
        command = table.@commands[0].as(Jennifer::Migration::TableBuilder::CreateIndex)
        command.fields.should eq([:uuid, :name])
        command.type.should eq(:uniq)
        command.lengths.empty?.should be_true
        command.orders.should eq({:uuid => :asc, :name => :desc})
      end
    end
  end

  describe "#drop_index" do
    it "creates DropIndex" do
      table = change_table_expr
      table.drop_index(:uuid)
      command = table.@commands[0].as(Jennifer::Migration::TableBuilder::DropIndex)
      command.@fields.should eq([:uuid])
    end

    postgres_only do
      it do
        table = change_table_expr(:contacts)
        table.drop_index(:description)
        table.process
        Jennifer::Adapter.default_adapter.index_exists?(:contacts, [:description]).should be_false
      end

      it "drops indexes before columns" do
        table = change_table_expr(:addresses)
        table.drop_index(:street)
        table.drop_column(:street)
        table.process
        Jennifer::Adapter.default_adapter.index_exists?(:addresses, [:street]).should be_false
        Jennifer::Adapter.default_adapter.column_exists?(:addresses, :street).should be_false
      end
    end
  end

  describe "#add_foreign_key" do
    it do
      table = change_table_expr
      table.add_foreign_key("to_table", "column", "primary", "some_name")
      command = table.@commands[0].as(Jennifer::Migration::TableBuilder::CreateForeignKey)
      command.from_table.should eq(DEFAULT_TABLE)
      command.to_table.should eq("to_table")
      command.column.should eq("column")
      command.primary_key.should eq("primary")
      command.name.should eq("some_name")
    end

    postgres_only do
      it do
        table = change_table_expr(:contacts)
        table.add_foreign_key(:cities, column: :age)
        table.process
        Jennifer::Adapter.default_adapter.foreign_key_exists?(:contacts, column: :age).should be_true
      end
    end
  end

  describe "#drop_foreign_key" do
    it do
      table = change_table_expr
      table.drop_foreign_key("to_table", name: "some_name")
      command = table.@commands[0].as(Jennifer::Migration::TableBuilder::DropForeignKey)
      command.from_table.should eq(DEFAULT_TABLE)
      command.to_table.should eq("to_table")
      command.name.should eq("some_name")
    end

    postgres_only do
      it do
        table = change_table_expr(:passports)
        table.drop_foreign_key(:contact)
        table.process
        Jennifer::Adapter.default_adapter.foreign_key_exists?(:passports, :contact).should be_false
      end
    end
  end

  describe "#process" do
    pending "add" do
    end
  end
end
