require "./create_foreign_key"

module Jennifer
  module Migration
    module TableBuilder
      class CreateTable < Base
        getter fields = {} of String => DB_OPTIONS

        def process
          schema_processor.create_table(self)
          process_commands
        end

        {% for method in Jennifer::Adapter::TYPES %}
          def {{method.id}}(name, options = DB_OPTIONS.new)
            defaults = { :type => {{method}} } of Symbol => AAllowedTypes
            @fields[name.to_s] = defaults.merge(options)
            self
          end
        {% end %}

        def enum(name, values = [] of String, options = DB_OPTIONS.new)
          hash = ({ :type => :enum, :values => typed_array_cast(values, EAllowedTypes) } of Symbol => AAllowedTypes).merge(options)
          @fields[name.to_s] = hash
          self
        end

        def field(name, data_type, options = DB_OPTIONS.new)
          @fields[name.to_s] = ({ :sql_type => data_type } of Symbol => AAllowedTypes).merge(options)
          self
        end

        def reference(name)
          integer(name.to_s + "_id", {:type => :integer, :null => true})
        end

        def timestamps(options = DB_OPTIONS.new)
          timestamp(:created_at, {:null => true})
          timestamp(:updated_at, {:null => true})
        end

        def index(name : String, fields : Array(Symbol), type : Symbol? = nil, lengths : Hash(Symbol, Int32) = {} of Symbol => Int32, orders : Hash(Symbol, Symbol) = {} of Symbol => Symbol)
          @commands << CreateIndex.new(@name, name, fields, type, lengths, orders)
          self
        end

        def index(name : String, field : Symbol, type : Symbol? = nil, length : Int32? = nil, order : Symbol? = nil)
          index(
            name,
            [field],
            type: type,
            orders: (order ? {field => order.not_nil!} : {} of Symbol => Symbol),
            lengths: (length ? {field => length.not_nil!} : {} of Symbol => Int32)
          )
        end

        # Is an alias for `#index`
        def add_index(*args, **opts)
          index(*args, **opts)
        end

        # Creates a foreign key constraint to `to_table` table.
        def foreign_key(to_table, column = nil, primary_key = nil, name = nil)
          @commands << CreateForeignKey.new(@adapter, @name, to_table.to_s, column, primary_key, name)
          self
        end
      end
    end
  end
end
