module Jennifer
  module Migration
    module TableBuilder
      class CreateTable < Base
        def process
          adapter.create_table(self)
          @indexes.each(&.process)
        end

        {% for method in Jennifer::Adapter::TYPES %}
          def {{method.id}}(name, options = DB_OPTIONS.new)
            defaults = sym_hash({:type => {{method}}}, AAllowedTypes)
            @fields[name.to_s] = defaults.merge(options)
            self
          end
        {% end %}

        def enum(name, values = [] of String, options = DB_OPTIONS.new)
          hash = sym_hash({:type => :enum, :values => typed_array_cast(values, EAllowedTypes)}, AAllowedTypes).merge(options)
          @fields[name.to_s] = hash
          self
        end

        def field(name, data_type, options = DB_OPTIONS.new)
          @fields[name.to_s] = sym_hash({:sql_type => data_type}, AAllowedTypes).merge(options)
          self
        end

        def reference(name)
          integer(name.to_s + "_id", {:type => :integer, :null => true})
        end

        def timestamps(options = DB_OPTIONS.new)
          timestamp(:created_at, {:null => true})
          timestamp(:updated_at, {:null => true})
        end

        def add_index(name : String, fields : Array(Symbol), type : Symbol? = nil, lengths : Hash(Symbol, Int32) = {} of Symbol => Int32, orders : Hash(Symbol, Symbol) = {} of Symbol => Symbol)
          @indexes << CreateIndex.new(@name, name, fields, type, lengths, orders)
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
      end
    end
  end
end
