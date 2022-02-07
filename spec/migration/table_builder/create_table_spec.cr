require "./spec_helper"

private def create_table_expr
  Jennifer::Migration::TableBuilder::CreateTable.new(Jennifer::Adapter.default_adapter, DEFAULT_TABLE)
end

describe Jennifer::Migration::TableBuilder::CreateTable do
  describe "#process" do
    pending "add" do
    end
  end

  pending "add tests for all types" do
  end

  describe "#integer" do
    it "creates enum field" do
      table = create_table_expr
      table.integer(:column, {:null => false})
      table.fields["column"].should eq({:type => :integer, :null => false})
    end
  end

  describe "#enum" do
    it "creates enum field" do
      table = create_table_expr
      table.enum(:column, ["one", "two"], {:null => false})
      table.fields["column"].should eq({:type => :enum, :values => ["one", "two"], :null => false})
    end
  end

  describe "#field" do
    it "creates field with given type" do
      table = create_table_expr
      table.field(:column, :data_type, {:null => false})
      table.fields["column"].should eq({:sql_type => :data_type, :null => false})
    end
  end

  describe "#reference" do
    it "creates column based on given field" do
      table = create_table_expr
      table.reference(:user)
      table.fields["user_id"].should eq({:type => :bigint, :null => true})

      command = table.@commands[0].as(Jennifer::Migration::TableBuilder::CreateForeignKey)
      command.from_table.should eq(DEFAULT_TABLE)
      command.to_table.should eq("users")
      command.column.should eq("user_id")
      command.primary_key.should eq("id")
      command.name.starts_with?("fk_cr_").should be_true
    end

    describe "polymorphic" do
      it "adds foreign and polymorphic columns" do
        table = create_table_expr
        table.reference(:user, options: {:polymorphic => true})
        table.fields["user_id"].should eq({:polymorphic => true, :type => :bigint, :null => true})
        table.fields["user_type"].should eq({:type => :string, :null => true})
        table.@commands.should be_empty
      end
    end
  end

  describe "#timestamps" do
    it "adds created_at and updated_at fields" do
      table = create_table_expr
      table.timestamps
      table.fields["created_at"].should eq({:type => :timestamp, :null => false})
      table.fields["updated_at"].should eq({:type => :timestamp, :null => false})
    end
  end

  describe "#index" do
    context "with named arguments" do
      it do
        table = create_table_expr
        table.index(name: "nodes_uuid_index", field: :uuid, type: :uniq, order: :asc)
        command = table.@commands[0].as(Jennifer::Migration::TableBuilder::CreateIndex)
        command.fields.should eq([:uuid])
        command.type.should eq(:uniq)
        command.lengths.empty?.should be_true
        command.orders[:uuid].should eq(:asc)
        command.index_name.should eq("nodes_uuid_index")
      end
    end

    context "with index name" do
      it do
        table = create_table_expr
        table.index(:uuid, :uniq, "nodes_uuid_index", length: 10, order: :asc)
        command = table.@commands[0].as(Jennifer::Migration::TableBuilder::CreateIndex)
        command.fields.should eq([:uuid])
        command.type.should eq(:uniq)
        command.lengths[:uuid].should eq(10)
        command.orders[:uuid].should eq(:asc)
        command.index_name.should eq("nodes_uuid_index")
      end
    end

    context "with plain arguments and specified length" do
      it do
        table = create_table_expr
        table.index(:uuid, :uniq, length: 10)
        command = table.@commands[0].as(Jennifer::Migration::TableBuilder::CreateIndex)
        command.fields.should eq([:uuid])
        command.type.should eq(:uniq)
        command.lengths[:uuid].should eq(10)
        command.index_name.should eq("test_table_uuid_idx")
      end
    end

    context "with multiple fields" do
      it do
        table = create_table_expr
        table.index([:uuid, :name], :uniq, orders: {:uuid => :asc, :name => :desc})
        command = table.@commands[0].as(Jennifer::Migration::TableBuilder::CreateIndex)
        command.fields.should eq([:uuid, :name])
        command.type.should eq(:uniq)
        command.lengths.empty?.should be_true
        command.orders.should eq({:uuid => :asc, :name => :desc})
        command.index_name.should eq("test_table_uuid_name_idx")
      end
    end
  end

  describe "#foreign_key" do
    it do
      table = create_table_expr
      table.foreign_key("tests", "column", "primary", "name")
      command = table.@commands[0].as(Jennifer::Migration::TableBuilder::CreateForeignKey)
      command.from_table.should eq(DEFAULT_TABLE)
      command.to_table.should eq("tests")
      command.column.should eq("column")
      command.primary_key.should eq("primary")
      command.name.should eq("name")
    end
  end
end
