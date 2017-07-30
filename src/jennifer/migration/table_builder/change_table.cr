module Jennifer
  module Migration
    module TableBuilder
      class ChangeTable < Base
        getter changed_columns, drop_columns, drop_index, new_table_rename

        def initialize(name)
          super
          @changed_columns = {} of String => DB_OPTIONS
          @drop_columns = [] of String
          @drop_index = [] of String
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
            sym_hash_cast(options, AAllowedTypes).merge(sym_hash({
              :new_name => new_name,
              :type     => type,
            }, EAllowedTypes))
          self
        end

        def add_column(name, type : Symbol, options = DB_OPTIONS.new)
          @fields[name.to_s] = sym_hash_cast(options, AAllowedTypes).merge(sym_hash({
            :type => type,
          }, AAllowedTypes))
          self
        end

        def drop_column(name)
          @drop_columns << name.to_s
          self
        end

        # add_index("index_name", [:field1, :field2], { :length => { :field1 => 2, :field2 => 3 }, :order => { :field1 => :asc }})
        # add_index("index_name", [:field1], { :length => { :field1 => 2, :field2 => 3 }, :order => { :field1 => :asc }})
        def add_index(name : String, fields : Array(Symbol), type : Symbol, length = {} of Symbol => Int32?, order = {} of Symbol => Symbol?)
          @indexes[name.to_s] =
            sym_hash(
              {
                :_fields => typed_array_cast(fields, EAllowedTypes),
                :type    => type,
                :length  => sym_hash_cast(length, EAllowedTypes),
                :order   => sym_hash_cast(order, EAllowedTypes),
              },
              HAllowedTypes
            )
          self
        end

        def add_index(name, field : Symbol, type : Symbol, length : Int32? = nil, order : Symbol? = nil)
          add_index(name, [field], type: type, order: {field => order}, length: {field => length})
        end

        def drop_index(name)
          @drop_index << name.to_s
          self
        end

        def process
          @drop_columns.each { |c| Adapter.adapter.drop_column(@name, c) }
          @fields.each { |n, opts| Adapter.adapter.add_column(@name, n, opts) }
          @changed_columns.each do |n, opts|
            Adapter.adapter.change_column(@name, n, opts[:new_name], opts)
          end
          @indexes.each do |k, options|
            Adapter.adapter.add_index(@name, k, options)
          end
          @drop_index.each { |i| Adapter.adapter.drop_index(@name, i) }

          Adapter.adapter.rename_table(@name, @new_table_name) unless @new_table_name.empty?
        end
      end
    end
  end
end
