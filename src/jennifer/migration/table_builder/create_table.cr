module Jennifer
  module Migration
    module TableBuilder
      class CreateTable < Base
        DEFAULT_TYPES = [:string, :integer, :bool, :float, :double, :short, :timestamp,
                         :date_time, :blob, :var_string, :text, :json]

        def process
          Adapter.adapter.create_table(self)
          @indexes.each { |n, options| Adapter.adapter.add_index(@name, n, options) }
        end

        {% for method in DEFAULT_TYPES %}
          def {{method.id}}(name, options = Hash(Symbol, EAllowedTypes).new)
            defaults = sym_hash({:type => {{method}}}, EAllowedTypes)
            @fields[name.to_s] = defaults.merge(options)
            self
          end
        {% end %}

        def reference(name)
          @fields[name.to_s + "_id"] = {:type => :int, :null => true}
          self
        end

        def timestamps(options = {} of Symbol => EAllowedTypes)
          timestamp(:created_at)
          timestamp(:updated_at)
        end

        def index(name, field : String | Symbol, options = {} of Symbol => HAllowedTypes)
          index(name, [field], {:order => {field => options[:order]?}, :length => {field => options[:length]?}})
        end

        def index(name, fields : Array, options = {} of Symbol => HAllowedTypes)
          @indexes[name.to_s] =
            sym_hash({:_fields => fields, :length => {} of Symbol => Int32, :order => {} of Symbol => Symbol}, HAllowedTypes)
                       .merge(sym_hash(options, HAllowedTypes))
          self
        end
      end
    end
  end
end
