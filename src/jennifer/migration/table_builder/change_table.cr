require "./create_foreign_key"
require "./drop_foreign_key"

module Jennifer
  module Migration
    module TableBuilder
      # Component responsible for altering existing table based on specified columns and properties.
      #
      # ```
      # change_table(:contacts) do |t|
      #   t.rename_table :users
      #   t.add_column :name, :string, {:size => 30}
      #   t.drop_column :age
      # end
      # ```
      class ChangeTable < Base
        getter changed_columns, drop_columns, drop_index, new_table_name

        def initialize(adapter, name)
          super
          @changed_columns = {} of String => DbOptions
          @new_columns = {} of String => DbOptions
          @drop_columns = [] of String
          @new_table_name = ""
        end

        def explain
          "change_table :#{@name}"
        end

        # Renames table to the given *new_name*.
        #
        # ```
        # rename_table :users
        # ```
        def rename_table(new_name : String | Symbol)
          @new_table_name = new_name.to_s
          self
        end

        # Changes the column's definition according to the new options.
        #
        # See `#add_column` for details of the options you can use.
        #
        # Additional available options:
        #
        # * `:new_name` - specifies a new name for the column;
        # * `:default` - `:none` value drops any default value specified before.
        #
        # ```
        # change_column :description, {:new_name => "information"}
        #
        # change_column :price, {:default => :none}
        # ```
        def change_column(name : String | Symbol, type : Symbol? = nil,
                          options : Hash(Symbol, AAllowedTypes) = DbOptions.new)
          @changed_columns[name.to_s] = build_column_options(type, options)
          @changed_columns[name.to_s][:new_name] ||= name
          self
        end

        # Defines new column *name* of *type* with given *options*.
        #
        # The *type* argument should be one of the following supported data types (see *Jennifer::Adapter::TYPES*).
        #
        # You may use any type that isn't in this list as long as it is supported by your database by skipping *type*
        # and passing `sql_type` option.
        #
        # Available options are (none of these exists by default):
        # - `:array` - creates and array of given type;
        # - `:size` - requests a maximum column length; e.g. this is a number of characters in `string` column and
        # number of bytes for `text` or `integer`;
        # - `:null` - allows or disallows `NULL` values;
        # - `:primary` - adds primary key constraint to the column; ATM only one field may be a primary key;
        # - `:default` - the column's default value;
        # - `:auto_increment` - add autoincrement to the column;
        # - `:serial` - makes column `SERIAL`;
        # - `:sql_type` - allow to specify custom SQL data type (use this only when really required);
        # - `:as` - specify query for generated column;
        # - `:
        #
        # ```
        # add_column :picture, :blob
        # add_column :status, :string, {:size => 20, :default => "draft", :null => false}
        # add_column :skills, :text, {:array => true}
        # add_column :full_name, :string, {:generated => true, :as => "CONCAT(first_name, ' ', last_name)"}
        # ```
        def add_column(name : String | Symbol, type : Symbol? = nil,
                       options : Hash(Symbol, AAllowedTypes) = DbOptions.new)
          @new_columns[name.to_s] = build_column_options(type, options)
          self
        end

        # Drops column with given *name*.
        def drop_column(name : String | Symbol)
          @drop_columns << name.to_s
          self
        end

        # Adds a reference.
        #
        # The reference column is an `bigint` by default, *type* argument can be used to specify a different type.
        #
        # If *polymorphic* option is `true` - additional string field `"#{name}_type"` is created and foreign key is
        # not added.
        #
        # `:to_table`, `:column`, `:primary_key` and `:key_name` options are used to create a foreign key constraint.
        # See `Migration::Base#add_foreign_key` for details.
        #
        # ```
        # add_reference :user
        # add_reference :order, :integer
        # add_reference :taggable, {:polymorphic => true}
        # ```
        def add_reference(name, type : Symbol = :bigint, options : Hash(Symbol, AAllowedTypes) = DbOptions.new)
          column = Wordsmith::Inflector.foreign_key(name)
          is_null = options.has_key?(:null) ? options[:null] : true
          field_internal_type = options.has_key?(:sql_type) ? nil : type

          @new_columns[column.to_s] = build_column_options(field_internal_type, options.merge({:null => is_null}))
          if options[:polymorphic]?
            add_column("#{name}_type", :string, {:null => is_null})
          else
            add_foreign_key(
              (options[:to_table]? || Wordsmith::Inflector.pluralize(name)).as(String | Symbol),
              options[:column]?.as(String | Symbol?),
              options[:primary_key]?.as(String | Symbol?),
              options[:key_name]?.as(String?),
              on_update: options[:on_update]?.as(Symbol?) || DEFAULT_ON_EVENT_ACTION,
              on_delete: options[:on_delete]?.as(Symbol?) || DEFAULT_ON_EVENT_ACTION,
            )
          end
          self
        end

        # Drops the reference.
        #
        # *options* can include `:polymorphic`, `:to_table` and `:column` options. For more details see
        # `#add_reference`.
        def drop_reference(name, options : Hash(Symbol, AAllowedTypes) = DbOptions.new)
          column = Wordsmith::Inflector.foreign_key(name)
          if options[:polymorphic]?
            drop_column("#{name}_type")
            drop_column(column)
          else
            @commands << DropReference.new(
              @adapter,
              @name,
              (options[:to_table]? || Wordsmith::Inflector.pluralize(name)).to_s,
              options[:column]?.as(String | Symbol?)
            )
          end
          self
        end

        # Add `created_at` and `updated_at` timestamp columns.
        #
        # Argument *null* sets `:null` option for both columns.
        def add_timestamps(null : Bool = false)
          add_column(:created_at, :timestamp, {:null => null})
          add_column(:updated_at, :timestamp, {:null => null})
        end

        # Adds new index.
        #
        # For more details see `Migration::Base#add_index`
        def add_index(fields : Array(Symbol), type : Symbol? = nil, name : String? = nil,
                      lengths : Hash(Symbol, Int32) = {} of Symbol => Int32,
                      orders : Hash(Symbol, Symbol) = {} of Symbol => Symbol)
          @commands << CreateIndex.new(@adapter, @name, name, fields, type, lengths, orders)
          self
        end

        def add_index(field : Symbol, type : Symbol? = nil, name : String? = nil, length : Int32? = nil,
                      order : Symbol? = nil)
          add_index(
            [field],
            type,
            name,
            orders: (order ? {field => order.not_nil!} : {} of Symbol => Symbol),
            lengths: (length ? {field => length.not_nil!} : {} of Symbol => Int32)
          )
        end

        # Drops the index from the table.
        #
        # For more details see `Migration::Base#drop_index`.
        def drop_index(fields : Array(Symbol) = [] of Symbol, name : String? = nil)
          @commands << DropIndex.new(@adapter, @name, fields, name)
          self
        end

        def drop_index(field : Symbol? = nil, name : String? = nil)
          @commands << DropIndex.new(@adapter, @name, field ? [field] : %i(), name)
          self
        end

        # Creates a foreign key constraint to `to_table` table.
        #
        # For more details see `Migration::Base#add_foreign_key`.
        def add_foreign_key(to_table : String | Symbol, column = nil, primary_key = nil, name = nil, *,
                            on_update : Symbol = DEFAULT_ON_EVENT_ACTION, on_delete : Symbol = DEFAULT_ON_EVENT_ACTION)
          @commands << CreateForeignKey.new(
            @adapter,
            @name,
            to_table.to_s,
            column,
            primary_key,
            name,
            on_update,
            on_delete
          )
          self
        end

        # Drops foreign key of *to_table*.
        #
        # For more details see `Migration::Base#drop_foreign_key`.
        def drop_foreign_key(to_table : String | Symbol, column = nil, name = nil)
          @commands << DropForeignKey.new(@adapter, @name, to_table.to_s, column, name)
          self
        end

        def process
          high_priority_commands.each(&.process)
          @drop_columns.each { |name| schema_processor.drop_column(@name, name) }
          @new_columns.each { |new_name, opts| schema_processor.add_column(@name, new_name, opts) }
          @changed_columns.each do |old_name, opts|
            schema_processor.change_column(@name, old_name, opts[:new_name].as(String | Symbol), opts)
          end
          low_priority_commands.each(&.process)

          schema_processor.rename_table(@name, @new_table_name) unless @new_table_name.empty?
        end

        private def high_priority_commands
          @commands.select do |command|
            command.is_a?(DropForeignKey) || command.is_a?(DropIndex) || command.is_a?(DropReference)
          end
        end

        private def low_priority_commands
          @commands - high_priority_commands
        end
      end
    end
  end
end
