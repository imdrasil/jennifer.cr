module Jennifer
  module Migration
    # Migrations can manage the evolution of a schema used by a physical databases. It's a solution
    # to the common problem of adding a field to make a new feature work in your local
    # database, but being unsure of how to push that change to other developers and to the production
    # server. With migrations, you can describe the transformations in self-contained classes that can
    # be checked into version control systems and executed against another database that might be one,
    # two, or five versions behind.
    #
    # Example of a simple migration:
    #
    # ```
    # class AddMainFlagToContacts < Jennifer::Migration::Base
    #   def up
    #     create_table(:contacts) do |t|
    #       t.string :name
    #       t.string :number, {:null => false}
    #     end
    #   end
    #
    #   def down
    #     drop_table(:contacts)
    #   end
    # end
    # ```
    #
    # This migration will add a boolean flag to the contacts table and remove it if you're backing out
    # of the migration. It shows how all migrations have two methods `#up` and `#down` that describes
    # the transformations required to implement or remove the migration. These methods can consist of both
    # the migration specific methods like `#create_table` and `#drop_table`, but may also contain regular
    # `Crystal` code for generating data needed for the transformations.
    #
    # By default each migration invocation (both `up` and `down`) are wrapped into a transaction but not all
    # RDBMS support transactional schema changes (like MySQL). To specify additional mechanism to rollback
    # after failed invocation you can chose 2 option: run reverse method (`down` for `up` and vise verse) or
    # invoke special callback.
    #
    # Using reverse direction:
    #
    # ```
    # Jennifer::Config.configure do |conf|
    #   # ...
    #   conf.migration_failure_handler_method = "reverse_direction"
    # end
    #
    # class AddMainFlagToContacts < Jennifer::Migration::Base
    #   def up
    #     change_table(:contacts) do |t|
    #       t.add_column :main, :bool, default: true
    #     end
    #   end
    #
    #   def down
    #     change_table(:contacts) do |t|
    #       t.drop_column :main if column_exists?(:contacts, :main)
    #     end
    #   end
    # end
    # ```
    #
    # Using callbacks:
    #
    # ```
    # Jennifer::Config.configure do |conf|
    #   # ...
    #   conf.migration_failure_handler_method = "callback"
    # end
    #
    # class AddMainFlagToContacts < Jennifer::Migration::Base
    #   def up
    #     change_table(:contacts) do |t|
    #       t.add_column :main, :bool, default: true
    #     end
    #   end
    #
    #   def after_up_failure
    #     change_table(:contacts) do |t|
    #       t.drop_column :main if column_exists?(:contacts, :main)
    #     end
    #   end
    #
    #   def down
    #     change_table(:contacts) do |t|
    #       t.drop_column :main
    #     end
    #   end
    #
    #   def after_down_failure
    #     change_table(:contacts) do |t|
    #       t.add_column :main, :bool, default: true unless column_exists?(:contacts, :main)
    #     end
    #   end
    # end
    # ```
    #
    # Such sort of behavior is useful when you have complex migration with several separate
    # changes.
    #
    # Also you can disable automatic transaction passing `false` to `.with_transaction` in a migration class body:
    #
    # ```
    # class AddMainFlagToContacts < Jennifer::Migration::Base
    #   with_transaction false
    #
    #   def up
    #     # ...
    #   end
    #
    #   def down
    #     # ...
    #   end
    # end
    # ```
    abstract class Base
      module AbstractClassMethods
        # Returns migration version - timestamp part of a class file name.
        abstract def version
      end

      extend AbstractClassMethods

      macro inherited
        # :nodoc:
        def self.version
          matched_data = File.basename(__FILE__, ".cr").match(/\A(\d)+/)
          return matched_data[0] if matched_data
          raise "#{self} migration class has no specified version"
        end
      end

      @@with_transaction = true

      # Database adapter connection instance.
      def adapter
        Adapter.default_adapter
      end

      # Returns where table with given *table* name exists.
      #
      # Delegate to `Adapter::Base#table_exists?`.
      def table_exists?(table : String | Symbol) : Bool
        adapter.table_exists?(table)
      end

      # Returns whether index for the *table` with *name* or *fields* exists.
      #
      # Delegate to `Adapter::Base#index_exists?`.
      def index_exists?(*args, **opts) : Bool
        adapter.index_exists?(*args, **opts)
      end

      # Returns whether column of *table* with *name* exists.
      #
      # Delegate to `Adapter::Base#column_exists?`.
      def column_exists?(table, name) : Bool
        adapter.column_exists?(table, name)
      end

      # Check whether view with given *name* exists.
      #
      # Delegate to `Adapter::Base#view_exists?`.
      def view_exists?(name : String | Symbol) : Bool
        adapter.view_exists?(name)
      end

      # Checks to see if a foreign key exists on a table for a given foreign key definition.
      #
      # Delegate to `Adapter::Base#foreign_key_exists?`.
      def foreign_key_exists?(from_table, to_table = nil, column = nil, name : String? = nil) : Bool
        adapter.foreign_key_exists?(from_table, to_table, column, name)
      end

      # Checks whether enum with given *name* exists.
      #
      # NOTE: PostreSQL only.
      def enum_exists?(name : String | Symbol) : Bool
        schema_processor.enum_exists?(name)
      end

      # Includes all transformations required to implement migration.
      #
      # By default it is executed under a transaction.
      abstract def up

      # Includes all transformations required to remove migration.
      #
      # By default it is executed under a transaction.
      abstract def down

      # Specify whether `#up`, `#down`, `#after_up_failure` and `#after_up_failure`
      # should be wrapped into a transaction.
      #
      # `true` by default.
      def self.with_transaction(value : Bool)
        @@with_transaction = value
      end

      # Returns whether `#up`, `#down`, `#after_up_failure` and `#after_up_failure`
      # are wrapped into a transaction.
      def self.with_transaction?
        @@with_transaction
      end

      # Creates a new table with the name *name*.
      #
      # ```
      # create_table(:contacts) do |t|
      #   t.field :name, :string, {:size => 30}
      # end
      # # or with shorthand
      # create_table(:contacts) do |t|
      #   t.string :name, {:size => 30}
      # end
      # ```
      #
      # By default, `#create_table` generates `id : Int32` primary key (`INTEGER` database type).
      # To prevent such behavior - set *id* argument to `false`.
      #
      # ```
      # create_table(:passport, false) do |t|
      #   t.string :puid, {:size => 10, :primary => true}
      #   t.string :name, {:size => 30}
      # end
      # ```
      #
      # For more details about new  table definition see `TableBuilder::CreateTable`.
      def create_table(name : String | Symbol, id : Bool = true, &)
        tb = TableBuilder::CreateTable.new(adapter, name)
        tb.bigint(:id, {:primary => true, :auto_increment => true}) if id
        yield tb
        process_builder(tb)
      end

      # Creates a new join table with the name created using the lexical order of the first 2 arguments.
      #
      # Created join table has no primary key, generated fields has no indexes.
      #
      # ```
      # # Creates a table called 'addresses_contacts'
      # create_join_table(:contacts, :addresses)
      # ```
      def create_join_table(table1 : String | Symbol, table2 : String | Symbol, table_name : String? = nil, &)
        create_table(table_name || adapter.class.join_table_name(table1, table2), false) do |t|
          t.bigint(Wordsmith::Inflector.foreign_key(Wordsmith::Inflector.singularize(table1.to_s)))
          t.bigint(Wordsmith::Inflector.foreign_key(Wordsmith::Inflector.singularize(table2.to_s)))
          yield t
        end
      end

      def create_join_table(table1, table2, table_name : String? = nil)
        create_join_table(table1, table2, table_name) { }
      end

      # Changes existing `table`.
      #
      # ```
      # change_table(:users) do |t|
      #   t.change_column :age, :integer, {:default => 0}
      #   t.add_column :description, :text
      #   t.drop_column :details
      # end
      # ```
      #
      # For more details see `TableBuilder::ChangeTable`.
      def change_table(table : String | Symbol, &)
        tb = TableBuilder::ChangeTable.new(adapter, table)
        yield tb
        process_builder(tb)
      end

      # Drops a *table* from the database.
      #
      # ```
      # drop_table(:users)
      # ```
      def drop_table(table : String | Symbol)
        process_builder(TableBuilder::DropTable.new(adapter, table))
      end

      # Drops the join table specified by the given arguments.
      #
      # See `#create_join_table` for details.
      #
      # ```
      # drop_join_table(:contacts, :addresses)
      # ```
      def drop_join_table(table1, table2)
        drop_table(adapter.class.join_table_name(table1, table2))
      end

      # Creates a new database view with the name *name*.
      #
      # ```
      # create_view(:youth_contacts, Jennifer::Query["contacts"].where { and(_age >= sql("14"), _age <= sql("24")) })
      # ```
      #
      # The source query can't have any arguments therefore all literals should be escaped manually and passed using
      # `QueryBuilder::Expression#sql`.
      def create_view(name : String | Symbol, source)
        process_builder(TableBuilder::CreateView.new(adapter, name.to_s, source))
      end

      # Drops a view from the database.
      #
      # ```
      # drop_view(:youth_contacts)
      # ```
      def drop_view(name : String | Symbol)
        process_builder(TableBuilder::DropView.new(adapter, name.to_s))
      end

      # Creates a new materialized database view with the name *name*.
      #
      # ```
      # create_view(:youth_contacts, Jennifer::Query["contacts"].where { and(_age >= sql("14"), _age <= sql("24")) })
      # ```
      #
      # # The source query can't have any arguments therefore all literals should be escaped manually and passed using
      # `QueryBuilder::Expression#sql`.
      #
      # NOTE: only Postgres supports this method.
      def create_materialized_view(name : String | Symbol, source)
        process_builder(schema_processor.build_create_materialized_view(name, source))
      end

      # Drops a materialized view from the database.
      #
      # ```
      # drop_materialized_view(:youth_contacts)
      # ```
      def drop_materialized_view(name : String | Symbol)
        process_builder(schema_processor.build_drop_materialized_view(name))
      end

      # Creates database enum
      #
      # ```
      # create_enum(:gender, %w(unspecified female male))
      # ```
      #
      # NOTE: not all adapters support this method.
      def create_enum(name : String | Symbol, values : Array(String))
        process_builder(schema_processor.build_create_enum(name, values))
      end

      # Drops a database enum by given *name*.
      #
      # ```
      # drop_enum(:gender)
      # ```
      #
      # NOTE: not all adapters support this method.
      def drop_enum(name : String | Symbol)
        process_builder(schema_processor.build_drop_enum(name))
      end

      # Changes database enum *name* by given *options*.
      #
      # ```
      # # To add new values
      # change_enum(:gender_enum, {:add_values => ["unknown"]})
      #
      # # To rename value
      # change_enum(:gender_enum, {:rename_values => ["unknown", "other"]})
      #
      # # To remove values
      # change_enum(:gender_enum, {:remove_values => ["other"]})
      # ```
      #
      # Also see `TableBuilder::CreateTable#enum`.
      #
      # It is possible to rename only one enum value at a time.
      #
      # NOTE: not all adapters support this method.
      def change_enum(name : String | Symbol, options : Hash(Symbol, Array(String)))
        process_builder(schema_processor.build_change_enum(name, options))
      end

      # Adds a new index to the *table_name*.
      #
      # The index will be named after the table and the column name(s), unless you  specify *name*.
      #
      # Allowed *type*:
      #
      # * `nil` (default)
      # * `:unique`
      # * `:fulltext` (MySQL only)
      # * `:spatial` (MySQL only)
      #
      # ```
      # add_index(:contacts, :email)
      # # => CREATE INDEX contacts_email_idx on contacts(email)
      # ```
      #
      # Creating a unique index:
      #
      # ```
      # add_index(:accounts, [:branch_id, :party_id], :unique)
      # # => CREATE UNIQUE INDEX accounts_branch_id_party_id_idx ON accounts(branch_id, party_id)
      # ```
      #
      # Creating a named index:
      #
      # ```
      # add_index(:accounts, [:branch_id, :party_id], :unique, name: "by_branch_party")
      # # => CREATE UNIQUE INDEX by_branch_party ON accounts(branch_id, party_id)
      # ```
      #
      # Creates an index with specific key length
      #
      # ```
      # add_index(:accounts, :name, name: "by_name", length: 10)
      # # => CREATE INDEX by_name ON accounts(name(10))
      # # for multiple fields
      #
      # add_index(:accounts, &i(name surname), name: 'by_name_surname', lengths: { :name => 10, :surname => 15 })
      # # => CREATE INDEX by_name_surname ON accounts(name(10), surname(15))
      # ```
      #
      # NOTE: SQLite doesn't support index length.
      #
      # Creating an index with a sort order:
      #
      # ```
      # add_index(:accounts, %i(branch_id party_id surname), orders: {:branch_id => :desc, :party_id => :asc})
      # # => CREATE INDEX by_branch_desc_party ON accounts(branch_id DESC, party_id ASC, surname)
      # ```
      #
      # NOTE: MySQL only supports index order from 8.0.1 onwards (earlier versions will raise an exception).
      def add_index(table_name : String | Symbol, fields : Array(Symbol), type : Symbol? = nil, name : String? = nil,
                    lengths : Hash(Symbol, Int32) = {} of Symbol => Int32,
                    orders : Hash(Symbol, Symbol) = {} of Symbol => Symbol)
        process_builder(TableBuilder::CreateIndex.new(adapter, table_name.to_s, name, fields, type, lengths, orders))
      end

      def add_index(table_name : String | Symbol, field : Symbol, type : Symbol? = nil, name : String? = nil,
                    length : Int32? = nil, order : Symbol? = nil)
        add_index(
          table_name,
          [field],
          type,
          name,
          orders: (order ? {field => order.not_nil!} : {} of Symbol => Symbol),
          lengths: (length ? {field => length.not_nil!} : {} of Symbol => Int32)
        )
      end

      # Removes the given index from the table.
      #
      # ```
      # drop_index(:accounts, :branch_id)
      # ```
      #
      # Drop the index on multiple fields
      #
      # ```
      # drop_index(:accounts, %i(branch_id party_id))
      # ```
      # Drop index with specific name:
      #
      # ```
      # drop_index(:accounts, name: "by_branch_name")
      # ```
      def drop_index(table : String | Symbol, fields : Array(Symbol) = [] of Symbol, name : String? = nil)
        process_builder(TableBuilder::DropIndex.new(adapter, table, fields, name))
      end

      def drop_index(table : String | Symbol, field : Symbol?, name : String? = nil)
        process_builder(TableBuilder::DropIndex.new(adapter, table, field ? [field] : %i(), name))
      end

      # Adds a new foreign key.
      #
      # *from_table* is the table with the key column, *to_table* contains the referenced primary key.
      #
      # The foreign key will be named after the following pattern: `fk_cr_<identifier>`. `identifier` is a 10
      # character long string which is deterministically generated from the `from_table` and `column`. A custom name
      # can be specified with the *name* argument.
      #
      # ```
      # add_foreign_key(:comments, :posts)
      # ```
      #
      # Creating a foreign key with specific primary and foreign keys
      #
      # ```
      # add_foreign_key(:comments, :posts, column: :article_id, primary: :uid)
      # ```
      #
      # Creating a foreign key with a specific name
      #
      # ```
      # add_foreign_key(:comments, :posts, name: "comments_posts_fk")
      # ```
      #
      # Specify `ON DELETE` or `ON UPDATE` action:
      #
      # ```
      # add_foreign_key(:comments, :posts, on_delete: :cascade)
      # ```
      #
      # Supported values: `:no_action`, `:restrict` (default), `:cascade`, `:set_null`.
      def add_foreign_key(from_table : String | Symbol, to_table : String | Symbol, column : String | Symbol? = nil,
                          primary_key : String | Symbol? = nil, name : String? = nil,
                          on_update : Symbol = TableBuilder::Base::DEFAULT_ON_EVENT_ACTION,
                          on_delete : Symbol = TableBuilder::Base::DEFAULT_ON_EVENT_ACTION)
        process_builder(
          TableBuilder::CreateForeignKey.new(
            adapter,
            from_table.to_s,
            to_table.to_s,
            column,
            primary_key,
            name,
            on_update,
            on_delete
          )
        )
      end

      # Removes the given foreign key from *from_table* to *to_table*.
      #
      # Arguments:
      # - *column* - the foreign key column name on current_table; defaults to
      # `Wordsmith::Inflector.foreign_key(Wordsmith::Inflector.singularize(to_table));
      # - *primary_key* - the primary key column name on *to_table*. Defaults to `"id"`;
      # - *name* - the constraint name. Defaults to `"fc_cr_<identifier>".
      #
      # ```
      # drop_foreign_key(:accounts, :branches)
      # ```
      #
      # Removes foreign key with specific column:
      #
      # ```
      # drop_foreign_key(:accounts, :branches, :column_name)
      # ```
      #
      # Removes foreign key with specific name:
      #
      # ```
      # drop_foreign_key(:accounts, :branches, name: "special_fk_name")
      # ```
      def drop_foreign_key(from_table : String | Symbol, to_table : String | Symbol, column : String | Symbol? = nil,
                           name : String? = nil)
        process_builder(
          TableBuilder::DropForeignKey.new(adapter, from_table.to_s, to_table.to_s, column, name)
        )
      end

      # Executes given string SQL.
      #
      # ```
      # exec <<-SQL
      #   ALTER TABLE profiles
      #     ADD CONSTRAINT type
      #     CHECK (type IN('FacebookProfile', 'TwitterProfile'))
      # SQL
      # ```
      def exec(string : String)
        process_builder(TableBuilder::Raw.new(adapter, string))
      end

      # `#up` failure handler if `migration_failure_handler_method` is set to `:callback`.
      #
      # By default it is executed under a transaction.
      def after_up_failure
      end

      # `#down` failure handler if `migration_failure_handler_method` is set to `:callback`.
      #
      # By default it is executed under a transaction.
      def after_down_failure
      end

      private delegate schema_processor, to: adapter

      private def process_builder(builder)
        builder.process
        puts "  * #{builder.explain}" if Jennifer::Config.config.verbose_migrations
      end

      # Returns migration timestamp.
      def self.version
        raise AbstractMethod.new(self, :version)
      end

      # Returns all existing migration timestamps based on available classes.
      def self.versions
        migrations.keys
      end

      # Returns all available migration classes.
      def self.migrations
        {% begin %}
          {% if @type.all_subclasses.size > 0 %}
            {
              {% for model in @type.all_subclasses %}
                {{model.id}}.version => {{model.id}},
              {% end %}
            }
          {% else %}
            {} of String => Jennifer::Migration::Base.class
          {% end %}
        {% end %}
      end
    end
  end
end

require "../adapter/schema_processor"
