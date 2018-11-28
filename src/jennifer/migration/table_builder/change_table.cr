require "./create_foreign_key"
require "./drop_foreign_key"

module Jennifer
  module Migration
    module TableBuilder
      class ChangeTable < Base
        getter changed_columns, drop_columns, drop_index, new_table_name

        def initialize(adapter, name)
          super
          @changed_columns = {} of String => DB_OPTIONS
          @new_columns = {} of String => DB_OPTIONS
          @drop_columns = [] of String
          @new_table_name = ""
        end

        def rename_table(new_name)
          @new_table_name = new_name.to_s
          self
        end

        # Defines new field *name* of type *data_type* with with given *options*.
        #
        # *type* can be avoid if `sql_type` option is specified.
        #
        # Available options:
        # - new_name
        # - serial
        # - sql_type
        # - size
        # - null
        # - primary
        # - default
        # - auto_increment
        def change_column(name, type : Symbol? = nil, options = DB_OPTIONS.new)
          if type.nil? && !options.has_key?(:sql_type)
            raise ArgumentError.new("Both type and sql_type can't be blank")
          end
          @changed_columns[name.to_s] =
            Ifrit.sym_hash_cast(options, AAllowedTypes).merge({ :type => type } of Symbol => EAllowedTypes)
          @changed_columns[name.to_s][:new_name] ||= name
          self
        end

        # Defines new field *name* of type *data_type* with with given *options*.
        #
        # *type* can be avoid if `sql_type` option is specified.
        #
        # Available options:
        # - serial
        # - sql_type
        # - size
        # - null
        # - primary
        # - default
        # - auto_increment
        def add_column(name, type : Symbol? = nil, options = DB_OPTIONS.new)
          if type.nil? && !options.has_key?(:sql_type)
            raise ArgumentError.new("Both type and sql_type can't be blank")
          end
          @new_columns[name.to_s] =
            Ifrit.sym_hash_cast(options, AAllowedTypes).merge({ :type => type } of Symbol => AAllowedTypes)
          self
        end

        def drop_column(name)
          @drop_columns << name.to_s
          self
        end

        # TODO: add more documentation.

        # Adds index.
        #
        # ```
        # t.add_index("index_name", [:field1, :field2], length: { :field1 => 2, :field2 => 3 }, orders: { :field1 => :asc }})
        # ```
        def add_index(name : String, fields : Array(Symbol), type : Symbol? = nil, lengths : Hash(Symbol, Int32) = {} of Symbol => Int32, orders : Hash(Symbol, Symbol) = {} of Symbol => Symbol)
          @commands << CreateIndex.new(@adapter, @name, name, fields, type, lengths, orders)
          self
        end

        def add_index(name : String, field : Symbol, type : Symbol? = nil, length : Int32? = nil, order : Symbol? = nil)
          add_index(
            name,
            [field],
            type: type,
            orders: (order ? {field => order.not_nil!} : {} of Symbol => Symbol),
            lengths: (length ? {field => length.not_nil!} : {} of Symbol => Int32)
          )
        end

        # Drops index by given *name*.
        def drop_index(name)
          @commands << DropIndex.new(@adapter, @name, name.to_s)
          self
        end

        # Creates a foreign key constraint to `to_table` table.
        #
        # Arguments:
        # - *column* - the foreign key column name on current_table. Defaults to `Inflector.foreign_key(Inflector.singularize(to_table))
        # - *primary_key* - the primary key column name on *to_table*. Defaults to `"id"`
        # - *name* - the constraint name. Defaults to `"fc_cr_<identifier>"
        def add_foreign_key(to_table, column = nil, primary_key = nil, name = nil)
          @commands << CreateForeignKey.new(@adapter, @name, to_table.to_s, column, primary_key, name)
          self
        end

        # Drops foreign key of *to_table*.
        def drop_foreign_key(to_table, name = nil)
          @commands << DropForeignKey.new(@adapter, @name, to_table.to_s, name)
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
