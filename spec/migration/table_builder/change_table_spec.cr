require "./spec_helper"

def change_table_expr
  Jennifer::Migration::TableBuilder::ChangeTable.new(Jennifer::Adapter.default_adapter, DEFAULT_TABLE)
end

describe Jennifer::Migration::TableBuilder::ChangeTable do
  describe "#rename_table" do
    it do
      table = change_table_expr
      table.rename_table("renamed_table")
      table.new_table_name.should eq("renamed_table")
    end
  end

  describe "#change_column" do
    it do
      table = change_table_expr
      table.change_column(:name, :integer)
      table.changed_columns["name"].should eq({ :new_name => :name, :type => :integer })
    end

    context "with specified type" do
      it do
        table = change_table_expr
        table.change_column(:name, :integer, { :new_name => :new_name, :null => false })
        table.changed_columns["name"].should eq({ :new_name => :new_name, :type => :integer, :null => false })
      end
    end

    context "with specified sql type in options" do
      it do
        table = change_table_expr
        table.change_column(:name, options: { :new_name => :new_name, :null => false, :sql_type => "SOME_TYPE" })
        table.changed_columns["name"].should eq({ :new_name => :new_name, :type => nil, :null => false, :sql_type => "SOME_TYPE" })
      end
    end

    context "with specified type only in options" do
      it do
        table = change_table_expr
        expect_raises(ArgumentError) do
          table.change_column(:name, options: { :new_name => :new_name, :null => false, :type => :integer })
        end
      end
    end
  end

  describe "#add_column" do
    it do
      table = change_table_expr
      table.add_column(:name, :integer)
      table.@new_columns["name"].should eq({ :type => :integer })
    end

    context "with specified type" do
      it do
        table = change_table_expr
        table.add_column(:name, :integer, { :null => false })
        table.@new_columns["name"].should eq({ :type => :integer, :null => false })
      end
    end

    context "with specified sql type in options" do
      it do
        table = change_table_expr
        table.add_column(:name, options: { :null => false, :sql_type => "SOME_TYPE" })
        table.@new_columns["name"].should eq({ :type => nil, :null => false, :sql_type => "SOME_TYPE" })
      end
    end

    context "with specified type only in options" do
      it do
        table = change_table_expr
        expect_raises(ArgumentError) do
          table.add_column(:name, options: { :null => false, :type => :integer })
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
  end

  describe "#add_reference" do
    it "creates column based on given field" do
      table = change_table_expr
      table.add_reference(:user)
      table.@new_columns["user_id"].should eq({ :type => :integer, :null => true })

      command = table.@commands[0].as(Jennifer::Migration::TableBuilder::CreateForeignKey)
      command.from_table.should eq(DEFAULT_TABLE)
      command.to_table.should eq("users")
      command.column.should eq("user_id")
      command.primary_key.should eq("id")
      command.name.starts_with?("fk_cr_").should be_true
    end

    describe "polymorphic" do
      it "adds foreign and polymorphic columns" do
        table = change_table_expr
        table.add_reference(:user, options: { :polymorphic => true })
        table.@new_columns["user_id"].should eq({ :polymorphic => true, :type => :integer, :null => true })
        table.@new_columns["user_type"].should eq({ :type => :string, :null => true })
        table.@commands.should be_empty
      end
    end
  end

  describe "#drop_reference" do
    it do
      table = change_table_expr
      table.drop_reference(:user)
      table.drop_columns.should eq(["user_id"])

      command = table.@commands[0].as(Jennifer::Migration::TableBuilder::DropForeignKey)
      command.from_table.should eq(DEFAULT_TABLE)
      command.to_table.should eq("users")
      command.name.starts_with?("fk_cr_").should be_true
    end

    describe "polymorphic" do
      it do
        table = change_table_expr
        table.drop_reference(:user, options: { :polymorphic => true })
        table.drop_columns.should eq(["user_id", "user_type"])
        table.@commands.should be_empty
      end
    end
  end

  describe "#add_timestamps" do
    it "creates updated_at and created_at columns" do
      table = change_table_expr
      table.add_timestamps
      table.@new_columns["created_at"].should eq({ :type => :timestamp, :null => false })
      table.@new_columns["updated_at"].should eq({ :type => :timestamp, :null => false })
    end
  end

  describe "#add_index" do
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
        table.add_index([:uuid, :name], :uniq, orders: { :uuid => :asc, :name => :desc })
        command = table.@commands[0].as(Jennifer::Migration::TableBuilder::CreateIndex)
        command.fields.should eq([:uuid, :name])
        command.type.should eq(:uniq)
        command.lengths.empty?.should be_true
        command.orders.should eq({ :uuid => :asc, :name => :desc })
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
  end

  describe "#process" do
    pending "add" do
    end
  end
end
