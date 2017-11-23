module Jennifer
  module Migration
    abstract class Base
      delegate create_data_type, to: Adapter.adapter
      delegate table_exists?, index_exists?, column_exists?, view_exists?, to: Adapter.adapter

      abstract def up
      abstract def down

      def self.version
        to_s[-17..-1]
      end

      def create_table(name, id : Bool = true)
        tb = TableBuilder::CreateTable.new(name)
        tb.integer(:id, {:primary => true, :auto_increment => true}) if id
        yield tb
        tb.process
      end

      # Creates join table; raises table builder to given block
      def create_join_table(table1, table2, table_name : String? = nil)
        create_table(table_name || Adapter.adapter_class.join_table_name(table1, table2), false) do |tb|
          tb.integer(table1.to_s.singularize.foreign_key)
          tb.integer(table2.to_s.singularize.foreign_key)
          yield tb
        end
      end

      # Creates join table.
      def create_join_table(table1, table2, table_name : String? = nil)
        create_join_table(table1, table2, table_name) { }
      end

      def drop_join_table(table1, table2)
        drop_table(Adapter.adapter_class.join_table_name(table1, table2))
      end

      def exec(string)
        TableBuilder::Raw.new(string).process
      end

      def drop_table(name)
        TableBuilder::DropTable.new(name).process
      end

      def change_table(name : String | Symbol)
        tb = TableBuilder::ChangeTable.new(name)
        yield tb
        tb.process
      end

      def create_view(name : String | Symbol, source)
        TableBuilder::CreateView.new(name.to_s, source).process
      end

      def drop_view(name : String | Symbol)
        TableBuilder::DropView.new(name.to_s).process
      end

      def add_index(table_name, name : String, fields : Array(Symbol), type : Symbol, lengths : Hash(Symbol, Int32) = {} of Symbol => Int32, orders : Hash(Symbol, Symbol) = {} of Symbol => Symbol)
        TableBuilder::CreateIndex.new(table_name, name, fields, type, lengths, orders).process
      end

      def add_index(table_name, name : String, field : Symbol, type : Symbol, length : Int32? = nil, order : Symbol? = nil)
        add_index(
          table_name,
          name,
          [field],
          type: type,
          orders: (order ? {field => order.not_nil!} : {} of Symbol => Symbol),
          lengths: (length ? {field => length.not_nil!} : {} of Symbol => Int32)
        )
      end

      def drop_index(table_name, name)
        TableBuilder::DropIndex.new(table_name, name).process
        self
      end

      def create_enum(name, options)
        raise BaseException.new("Current adapter doesn't support this method.")
      end

      def drop_enum(name)
        raise BaseException.new("Current adapter doesn't support this method.")
      end

      def change_enum(name, options)
        raise BaseException.new("Current adapter doesn't support this method.")
      end

      def self.versions
        migrations.map { |e| e.underscore.split("_").last }
      end

      macro def self.migrations
        {% begin %}
          {% if @type.all_subclasses.size > 0 %}
            [
              {% for model in @type.all_subclasses %}
                {{model.id}},
              {% end %}
            ]
          {% else %}
            [] of Jennifer::Migration::Base.class
          {% end %}
        {% end %}
      end
    end
  end
end
