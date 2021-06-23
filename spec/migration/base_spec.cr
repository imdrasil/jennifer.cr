require "../spec_helper"

describe Jennifer::Migration::Base do
  described_class = Jennifer::Migration::Base
  migration = CreateContacts.new

  describe ".versions" do
    it { described_class.versions.should eq(["20170119011451314", "20180909200027509"]) }
  end

  describe ".migrations" do
    it { described_class.migrations.should eq({"20170119011451314" => CreateContacts, "20180909200027509" => CreateNotes}) }
  end

  describe ".version" do
    it { CreateContacts.version.should eq("20170119011451314") }
  end

  describe ".with_transaction?" do
    it { CreateContacts.with_transaction?.should be_true }
    it { CreateNotes.with_transaction?.should be_false }
  end

  # TODO: add aka transactional schema tests for MySQL
  postgres_only do
    adapter = Jennifer::Adapter.default_adapter.as(Jennifer::Postgres::Adapter)

    describe "#create_table" do
      it "creates table" do
        migration.create_table(:test_table) do |t|
          t.integer :field
        end

        adapter.table_exists?(:test_table).should be_true
        adapter.column_exists?(:test_table, :field).should be_true
        adapter.column_exists?(:test_table, :id).should be_true
      end

      context "without id" do
        it "creates table" do
          migration.create_table(:test_table, id: false) { }
          adapter.table_exists?(:test_table).should be_true
          adapter.column_exists?(:test_table, :id).should be_false
        end
      end
    end

    describe "#create_join_table" do
      context "with block" do
        it do
          migration.create_join_table(:contacts, :addresses) do |t|
            t.integer :field
          end

          adapter.table_exists?(:addresses_contacts).should be_true
          adapter.column_exists?(:addresses_contacts, :address_id).should be_true
          adapter.column_exists?(:addresses_contacts, :contact_id).should be_true
          adapter.column_exists?(:addresses_contacts, :field).should be_true
        end
      end

      it do
        migration.create_join_table(:contacts, :addresses)

        adapter.table_exists?(:addresses_contacts).should be_true
        adapter.column_exists?(:addresses_contacts, :address_id).should be_true
        adapter.column_exists?(:addresses_contacts, :contact_id).should be_true
      end
    end

    describe "#change_table" do
      it do
        migration.create_table(:test_table) { }
        migration.change_table(:test_table) do |t|
          t.rename_table :new_table
          t.add_column :field, :integer
        end

        adapter.table_exists?(:test_table).should be_false
        adapter.table_exists?(:new_table).should be_true
        adapter.column_exists?(:new_table, :field).should be_true
      end
    end

    describe "#drop_table" do
      it do
        migration.create_table(:test_table) { }
        migration.drop_table(:test_table)

        adapter.table_exists?(:test_table).should be_false
      end
    end

    describe "#drop_join_table" do
      it do
        migration.create_join_table(:contacts, :addresses)
        migration.drop_join_table(:contacts, :addresses)

        adapter.table_exists?(:addresses_contacts).should be_false
      end
    end

    describe "#create_view" do
      it do
        migration.create_view(:youth_contacts, Jennifer::Query["contacts"].where { and(_age >= sql("14"), _age <= sql("24")) })

        adapter.view_exists?(:youth_contacts).should be_true
      end
    end

    describe "#drop_view" do
      it do
        migration.create_view(:youth_contacts, Jennifer::Query["contacts"])
        migration.drop_view(:youth_contacts)

        adapter.view_exists?(:youth_contacts).should be_false
      end
    end

    describe "#create_materialized_view" do
      pending "add"
    end

    describe "#drop_materialized_view" do
      pending "add"
    end

    describe "#create_enum" do
      it do
        migration.create_enum(:gender, %w(unspecified female male))

        adapter.enum_exists?(:gender).should be_true
      end
    end

    describe "#drop_enum" do
      it do
        migration.create_enum(:gender, %w(unspecified female male))
        migration.drop_enum(:gender)

        adapter.enum_exists?(:gender).should be_false
      end
    end

    describe "#change_enum" do
      it do
        void_transaction do
          begin
            migration.create_enum(:gender, %w(unspecified female male))
            migration.change_enum(:gender, {:add_values => ["other"]})

            adapter.enum_values(:gender).should eq(%w(unspecified female male other))
          ensure
            migration.drop_enum(:gender)
          end
        end
      end
    end

    describe "#add_index" do
      it do
        migration.create_table(:test_table) do |t|
          t.integer :field
        end
        migration.add_index(:test_table, :field)

        adapter.index_exists?(:test_table, [:field]).should be_true
      end
    end

    describe "#drop_index" do
      it do
        migration.create_table(:test_table) do |t|
          t.integer :field
        end
        migration.add_index(:test_table, :field)
        migration.drop_index(:test_table, :field)

        adapter.index_exists?(:test_table, [:field]).should be_false
      end
    end

    describe "#add_foreign_key" do
      it do
        migration.create_table(:test_table) do |t|
          t.integer :to_table_id
        end
        migration.create_table(:to_table) { }
        migration.add_foreign_key(:test_table, :to_table)

        adapter.foreign_key_exists?(:test_table, :to_table).should be_true
      end
    end

    describe "#drop_foreign_key" do
      it do
        migration.create_table(:test_table) do |t|
          t.integer :to_table_id
        end
        migration.create_table(:to_table) { }
        migration.add_foreign_key(:test_table, :to_table)
        migration.drop_foreign_key(:test_table, :to_table)

        adapter.foreign_key_exists?(:test_table, :to_table).should be_false
      end
    end

    describe "#exec" do
      it do
        migration.exec "CREATE TABLE test_table()"

        adapter.table_exists?(:test_table).should be_true
      end
    end
  end
end
