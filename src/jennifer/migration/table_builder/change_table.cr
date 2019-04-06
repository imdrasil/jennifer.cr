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
      #  end
      # ```
      class ChangeTable < Base
        getter changed_columns, drop_columns, drop_index, new_table_name

        def initialize(adapter, name)
          super
          @changed_columns = {} of String => DB_OPTIONS
          @new_columns = {} of String => DB_OPTIONS
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
        # change_column :description, { :new_name => "information" }
        #
        # change_column :price, { :default => :none }
        # ```
        def change_column(name : String | Symbol, type : Symbol? = nil, options : Hash(Symbol, AAllowedTypes) = DB_OPTIONS.new)
          @changed_columns[name.to_s] = build_column_options(type, options)
          @changed_columns[name.to_s][:new_name] ||= name
          self
        end

        # Defines new column *name* of *type* with given *options*.
        #
        # The *type* argument should be one of the following supported data types: `integer`, `short`, `bigint`,
        # `float`, `double`, `decimal`, `bool`, `string`, `char`, `text`, `var_string`, `varchar`, `timestamp`,
        # `date_time`, `blob`, `json`; PostgreSQL specific: `oid`, `numeric`, `char`, `blchar`, `uuid`, `timestamptz`,
        # `bytea`, `jsonb`, `xml`, `point`, `lseg`, `path`, `box`, `polygon`, `line`, `circle`; MySQL specific: `emum`,
        # `tinyint`.
        #
        # You may use any type not in this list as long as it is supported by your database by living *type* blank
        # and passing `sql_type` option.
        #
        # Available options are (none of these exists by default):
        # - `:array` - creates and array of given type;
        # - `:serial` - makes column `SERIAL`;
        # - `:sql_type` - allow to specify custom SQL data type;
        # - `:size` - requests a maximum column length; e.g. this is a number of characters in `string` column and
        # number of bytes for `text` or `integer`;
        # - `:null` - allows or disallows `NULL` values;
        # - `:primary` - adds primary key constraint to the column; ATM only one field may be a primary key;
        # - `:default` - the column's default value;
        # - `:auto_increment` - add autoincrement to the column.
        #
        # ```
        # add_column :picture, :blob
        #
        # add_column :status, :string, { :size => 20, :default => "draft", :null => false }
        #
        # add_column :skills, :text, { :array => true }
        # ```
        def add_column(name : String | Symbol, type : Symbol? = nil, options : Hash(Symbol, AAllowedTypes) = DB_OPTIONS.new)
          @new_columns[name.to_s] = build_column_options(type, options)
          self
        end

        # Drops column with given *name*.
        def drop_column(name : String | Symbol)
          @drop_columns << name.to_s
          self
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

        # Creates a foreign key constraint to `to_table` table.
        #
        # For more details see `Migration::Base#add_foreign_key`.
        def add_foreign_key(to_table : String | Symbol, column = nil, primary_key = nil, name = nil)
          @commands << CreateForeignKey.new(@adapter, @name, to_table.to_s, column, primary_key, name)
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
          @drop_columns.each { |c| schema_processor.drop_column(@name, c) }
          @new_columns.each { |n, opts| schema_processor.add_column(@name, n, opts) }
          @changed_columns.each do |n, opts|
            schema_processor.change_column(@name, n, opts[:new_name].as(String | Symbol), opts)
          end

          process_commands
          schema_processor.rename_table(@name, @new_table_name) unless @new_table_name.empty?
        end
      end
    end
  end
end
