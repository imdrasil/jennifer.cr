require "./create_foreign_key"
require "./drop_foreign_key"

module Jennifer
  module Migration
    module TableBuilder
      class ChangeTable < Base
        getter changed_columns, drop_columns, drop_index, new_table_rename

        def initialize(adapter, name)
          super
          @changed_columns = {} of String => DB_OPTIONS
          @new_columns = {} of String => DB_OPTIONS
          @drop_columns = [] of String
          @new_table_name = ""
        end

        def rename_table(new_name)
          new_table_name = new_name.to_s
          self
        end

        def change_column(old_name, type : Symbol? = nil, options = DB_OPTIONS.new)
          change_column(old_name, old_name, type, options)
        end

        def change_column(old_name, new_name, type : Symbol? = nil, options = DB_OPTIONS.new)
          @changed_columns[old_name.to_s] =
            sym_hash_cast(options, AAllowedTypes).merge(
            {
              :new_name => new_name,
              :type     => type,
            } of Symbol => EAllowedTypes)
          self
        end

        def add_column(name, type : Symbol, options = DB_OPTIONS.new)
          @new_columns[name.to_s] =
            sym_hash_cast(options, AAllowedTypes).merge({ :type => type } of Symbol => AAllowedTypes)
          self
        end

        def drop_column(name)
          @drop_columns << name.to_s
          self
        end

        # add_index("index_name", [:field1, :field2], { :length => { :field1 => 2, :field2 => 3 }, :order => { :field1 => :asc }})
        # add_index("index_name", [:field1], { :length => { :field1 => 2, :field2 => 3 }, :order => { :field1 => :asc }})
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

        def drop_index(name)
          @commands << DropIndex.new(@adapter, @name, name.to_s)
          self
        end

        def add_foreign_key(to_table, column = nil, primary_key = nil, name = nil)
          @commands << CreateForeignKey.new(@adapter, @name, to_table.to_s, column, primary_key, name)
          self
        end

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
