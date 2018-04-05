module Jennifer
  module Migration
    abstract class Base
      TABLE_NAME = "migration_versions"

      module AbstractClassMethods
        abstract def version
      end

      extend AbstractClassMethods

      macro delegate(*methods, to object, prefix pref = "")
        {% for method in methods %}
          def {{method.id}}(*args, **options)
            {{object.id}}.{{pref.id}}{{method.id}}(*args, **options)
          end

          def {{method.id}}(*args, **options)
            {{object.id}}.{{pref.id}}{{method.id}}(*args, **options) do |*yield_args|
              yield *yield_args
            end
          end
        {% end %}
      end

      delegate adapter, to: Adapter

      delegate create_data_type, to: adapter
      delegate table_exists?, index_exists?, column_exists?, view_exists?, to: adapter
      delegate schema_processor, to: adapter

      delegate create_table, create_join_table, drop_join_table, exec, drop_table,
        change_table, create_view, create_materialized_view, drop_materialized_view,
        drop_view, add_index, create_enum, drop_enum, change_enum,
        to: schema_processor, prefix: "build_"

      def adapter_class
        adapter.class
      end

      abstract def up
      abstract def down

      def self.version
        to_s[-17..-1]
      end

      def self.versions
        migrations.map { |e| e.underscore.split("_").last }
      end

      def self.migrations
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

require "../adapter/schema_processor"
