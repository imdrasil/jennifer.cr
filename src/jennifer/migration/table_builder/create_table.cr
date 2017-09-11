module Jennifer
  module Migration
    module TableBuilder
      class CreateTable < Base
        def process
          Adapter.adapter.create_table(self)
          @indexes.each { |n, options| Adapter.adapter.add_index(@name, n, options) }
        end

        {% for method in Jennifer::Adapter::TYPE_TRANSLATIONS.keys %}
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

        def index(name, field : String | Symbol, options = DB_OPTIONS.new)
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
