require "./sanitizer"

module Jennifer
  module Adapter
    module SqlNotation
      include Sanitizer

      def insert(obj : Model::Base)
        opts = obj.arguments_to_insert
        String.build do |s|
          s << "INSERT INTO " << obj.class.table_name
          unless opts[:fields].empty?
            s << "("
            opts[:fields].join(", ", s)
            s << ") VALUES ("
            opts[:args].join(", ", s) { |e| s << Adapter::SqlGenerator.escape(e) }
            s << ") "
          else
            s << " VALUES ()"
          end
        end
      end

      # Generates update request depending on given query and hash options. Allows
      # joins inside of query.
      def update(query, options : Hash)
        String.build do |s|
          s << "UPDATE " << query.table
          s << "\n"
          _joins = query._joins

          unless _joins.empty?
            where_clause(s, _joins[0].on)
            _joins[1..-1].join(" ", s) { |e| e.as_sql(s) }
          end
          s << " SET "
          options.join(", ", s) { |(k, v), s| s << k << " = " << Adapter::SqlGenerator.escape(v) }
          s << " "
          where_clause(s, query.tree)
        end
      end

      def old_update(query, options : Hash)
        esc = Adapter.adapter_class.escape_string(1)
        String.build do |s|
          s << "UPDATE " << query.table
          s << "\n"
          _joins = query._joins

          unless _joins.empty?
            where_clause(s, _joins[0].on)
            _joins[1..-1].map(&.as_sql).join(' ', s)
          end
          s << " SET "
          options.map { |k, v| "#{k.to_s}= #{esc}" }.join(", ", s)
          s << " "
          where_clause(s, query.tree)
        end
      end

      def json_path(path : QueryBuilder::JSONSelector)
        value =
          if path.path.is_a?(Number)
            quote("$[#{path.path.to_s}]")
          else
            quote(path.path)
          end
        "#{path.identifier}->#{value}"
      end

      def quote(value : String)
        "\"#{value.gsub(/\\/, "\&\&").gsub(/"/, "\"\"")}\""
      end
    end
  end
end
