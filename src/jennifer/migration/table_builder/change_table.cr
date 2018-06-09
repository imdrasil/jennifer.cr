module Jennifer
  module Migration
    module TableBuilder
      class ChangeTable < Base
        getter changed_columns, drop_columns, drop_index, new_table_rename

        def initialize(adapter, name)
          super
          @changed_columns = {} of String => DB_OPTIONS
          @drop_columns = [] of String
          @drop_index = [] of DropIndex
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
          @fields[name.to_s] =
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
          @indexes << CreateIndex.new(@adapter, @name, name, fields, type, lengths, orders)
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
          @drop_index << DropIndex.new(@adapter, @name, name.to_s)
          self
        end

        def process
          @drop_columns.each { |c| schema_processor.drop_column(@name, c) }
          @fields.each { |n, opts| schema_processor.add_column(@name, n, opts) }
          @changed_columns.each do |n, opts|
            schema_processor.change_column(@name, n, opts[:new_name].as(String | Symbol), opts)
          end
          @indexes.each(&.process)
          @drop_index.each(&.process)

          schema_processor.rename_table(@name, @new_table_name) unless @new_table_name.empty?
        end
      end
    end
  end
end
