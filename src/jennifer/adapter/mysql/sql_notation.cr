module Jennifer
  module Adapter
    module SqlNotation
      def insert(obj : Model::Base)
        opts = obj.arguments_to_insert
        String.build do |s|
          s << "INSERT INTO " << obj.class.table_name
          unless opts[:fields].empty?
            s << "("
            opts[:fields].join(", ", s)
            s << ") VALUES (" << Adapter.adapter_class.escape_string(opts[:fields].size) << ") "
          else
            s << " VALUES ()"
          end
        end
      end

      # Generates update request depending on given query and hash options. Allows
      # joins inside of query.
      def update(query, options : Hash)
        esc = Adapter.adapter_class.escape_string(1)
        String.build do |s|
          s << "UPDATE " << query.table
          s << "\n"
          _joins = query._joins

          unless _joins.empty?
            where_clause(s, _joins[0].on)
            _joins[1..-1].map(&.to_sql).join(' ', s)
          end
          where_clause(s, query.tree)

          s << " SET "
          options.map { |k, v| "#{k.to_s}= #{esc}" }.join(", ", s)
        end
      end
    end
  end
end
