require "./create_foreign_key"

module Jennifer
  module Migration
    module TableBuilder
      # Component responsible for creating a new table based on specified columns and properties.
      #
      # ```
      # create_table(:contacts) do |t|
      #   t.string :name, {:size => 30}
      #   t.integer :age
      #   t.integer :tags, {:array => true}
      #   t.decimal :ballance
      #   t.field :gender, :gender_enum
      #   t.timestamps true
      # end
      # ```
      class CreateTable < Base
        getter fields = {} of String => DB_OPTIONS

        def process
          schema_processor.create_table(self)
          process_commands
        end

        def explain
          "create_table :#{@name}"
        end

        {% for method in Jennifer::Adapter::TYPES %}
          # Defines new column *name* of type `{{method}}` with given *options*.
          #
          # For more details see `ChangeTable#add_column`.
          def {{method.id}}(name : String | Symbol, options = DB_OPTIONS.new)
            @fields[name.to_s] = build_column_options({{method}}, options)
            self
          end
        {% end %}

        # Defines new enum column *name* with given *options*.
        #
        # *values* argument specified allowed enum values.
        #
        # For more details see `ChangeTable#add_column`
        def enum(name : String | Symbol, values : Array(String), options : Hash(Symbol, AAllowedTypes) = DB_OPTIONS.new)
          options = Ifrit.sym_hash_cast(options, AAllowedTypes).merge!({ :values => Ifrit.typed_array_cast(values, EAllowedTypes) })
          @fields[name.to_s] = build_column_options(:enum, options)
          self
        end

        # Defines field *name* of type *type* with with given *options*.
        #
        # For more details see `ChangeTable#add_column`. The only difference is that *type* argument
        # is treated as SQL datatype - it works same way as specifying `:sql_type` parameter.
        #
        # ```
        # create_enum :gender_enum, %w(unspecified female male)
        #
        # create_table :users do |t|
        #   t.field :gender, :gender_enum
        # end
        # ```
        #
        # Migration above will create PostreSQL enum and a table with column of that type.
        def field(name : String | Symbol, type : Symbol | String, options : Hash(Symbol, AAllowedTypes) = DB_OPTIONS.new)
          @fields[name.to_s] = ({ :sql_type => type } of Symbol => AAllowedTypes).merge(options)
          self
        end

        # Alias for `#field`.
        def column(name, type, options = DB_OPTIONS.new)
          field(name, type, options)
        end

        # Adds a reference.
        #
        # The reference column is an `integer` by default, the *type` argument can be used to specify a different type.
        #
        # If *polymorphic* option is `true` - additional string field `"#{name}_type"` is created and foreign key is
        # not added.
        #
        # `:to_table`, `:column`, `:primary_key` and `:key_name` options are used to create a foreign key constraint.
        # See `Migration::Base#add_foreign_key` for details.
        #
        # ```
        # reference :user
        #
        # reference :order, :bigint
        #
        # reference :taggable, { :polymorphic => true }
        # ```
        def reference(name, type : Symbol = :integer, options : Hash(Symbol, AAllowedTypes) = DB_OPTIONS.new)
          column = Inflector.foreign_key(name)
          is_null = options.has_key?(:null) ? options[:null] : true

          integer(column, { :type => type, :null => is_null })
          if options[:polymorphic]?
            string("#{name}_type", { :null => is_null })
          else
            foreign_key(
              (options[:to_table]? || Inflector.pluralize(name)).as(String | Symbol),
              options[:column]?.as(String | Symbol?),
              options[:primary_key]?.as(String | Symbol?),
              options[:key_name]?.as(String?)
            )
          end
          self
        end

        # Defines `created_at` and `updated_at` timestamp fields.
        #
        # Argument *null* sets `:null` option for both fields.
        def timestamps(null = false)
          timestamp(:created_at, { :null => null })
          timestamp(:updated_at, { :null => null })
        end

        # Adds index.
        #
        # For more details see `Migration::Base#add_index`.
        def index(name : String, fields : Array(Symbol), type : Symbol? = nil,
                  lengths : Hash(Symbol, Int32) = {} of Symbol => Int32,
                  orders : Hash(Symbol, Symbol) = {} of Symbol => Symbol)
          @commands << CreateIndex.new(@adapter, @name, name, fields, type, lengths, orders)
          self
        end

        # ditto
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
        # For more details see `Migration::Base#add_foreign_key`.
        def foreign_key(to_table : String | Symbol, column = nil, primary_key = nil, name = nil)
          @commands << CreateForeignKey.new(@adapter, @name, to_table.to_s, column, primary_key, name)
          self
        end
      end
    end
  end
end
