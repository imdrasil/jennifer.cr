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
          hash = ({ :type => :enum, :values => Ifrit.typed_array_cast(values, EAllowedTypes) } of Symbol => AAllowedTypes).merge(options)
          @fields[name.to_s] = hash
          self
        end

        # Defines field *name* of type *type* with with given *options*.
        #
        # Given *type* is considered as sql type. Available options:
        # - serial
        # - sql_type
        # - size
        # - null
        # - primary
        # - default
        # - auto_increment
        def field(name, type, options = DB_OPTIONS.new)
          @fields[name.to_s] = ({ :sql_type => type } of Symbol => AAllowedTypes).merge(options)
          self
        end

        # Adds a reference.
        #
        # Defines foreign key field based on given relation name (*name*). By default it is integer and null value is allowed.
        def reference(name, to_table = Inflector.pluralize(name), primary_key = nil, key_name = nil)
          column = Inflector.foreign_key(name)
          integer(column, { :type => :integer, :null => true })
          foreign_key(to_table, column, primary_key, key_name)
        end

        # Defines `created_at` and `updated_at` timestamp fields.
        #
        # Argument *null* sets `:null` option to both fields.
        def timestamps(null = false)
          timestamp(:created_at, { :null => null })
          timestamp(:updated_at, { :null => null })
        end

        # Adds index.
        #
        # ```
        # t.index("index_name", [:field1, :field2], length: { :field1 => 2, :field2 => 3 }, orders: { :field1 => :asc }})
        # ```
        # TODO: add more documentation.
        def index(name : String, fields : Array(Symbol), type : Symbol? = nil, lengths : Hash(Symbol, Int32) = {} of Symbol => Int32, orders : Hash(Symbol, Symbol) = {} of Symbol => Symbol)
          @commands << CreateIndex.new(@adapter, @name, name, fields, type, lengths, orders)
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

        # Creates a foreign key constraint to `to_table` table.
        #
        # Arguments:
        # - *column* - the foreign key column name on current_table. Defaults to `Inflector.foreign_key(Inflector.singularize(to_table))
        # - *primary_key* - the primary key column name on *to_table*. Defaults to `"id"`
        # - *name* - the constraint name. Defaults to `"fc_cr_<identifier>"
        def foreign_key(to_table, column = nil, primary_key = nil, name = nil)
          @commands << CreateForeignKey.new(@adapter, @name, to_table.to_s, column, primary_key, name)
          self
        end
      end
    end
  end
end
