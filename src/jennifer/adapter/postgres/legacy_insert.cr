module Jennifer
  module Postgres
    class Adapter
      def scalar(_query, args : Array(DBAny) = [] of DBAny)
        time = Time.monotonic
        res = with_connection { |conn| conn.scalar(_query, args) }
        time = Time.monotonic - time
        Config.logger.debug { regular_query_message(time, _query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, _query, args)
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, _query, args)
      end

      def insert(obj : Model::Base)
        opts = obj.arguments_to_insert
        query = parse_query(sql_generator.insert(obj, obj.class.primary_auto_incrementable?), opts[:args])
        id = -1i64
        affected = 0i64
        if obj.class.primary_auto_incrementable?
          affected = exec(*query).rows_affected
          if affected != 0
            id = scalar("SELECT currval(pg_get_serial_sequence('#{obj.class.table_name}', '#{obj.class.primary_field_name}'))").as(Int64)
          end
        else
          affected = exec(*query).rows_affected
        end

        ExecResult.new(id, affected)
      end
    end

    class SQLGenerator
      def self.insert(obj : Model::Base, with_primary_field = true)
        opts = obj.arguments_to_insert
        String.build do |s|
          s << "INSERT INTO " << obj.class.table_name
          unless opts[:fields].empty?
            s << "("
            opts[:fields].join(", ", s)
            s << ") VALUES (" << escape_string(opts[:fields].size) << ") "
          else
            s << " DEFAULT VALUES"
          end
        end
      end
    end
  end
end
