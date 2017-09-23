module Jennifer
  module Adapter
    module Executables
      TICKS_PER_MICROSECOND = 10

      def exec(_query, args = [] of DB::Any)
        time = Time.now.ticks
        res = with_connection { |conn| args.empty? ? conn.exec(_query) : conn.exec(_query, args) }
        time = Time.now.ticks - time
        Config.logger.debug { regular_query_message(time / TICKS_PER_MICROSECOND, _query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, _query, args)
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, _query, args)
      end

      def query(_query, args = [] of DB::Any)
        time = Time.now.ticks
        res =
          if args.empty?
            with_connection { |conn| conn.query(_query) { |rs| time = Time.now.ticks - time; yield rs } }
          else
            with_connection { |conn| conn.query(_query, args) { |rs| time = Time.now.ticks - time; yield rs } }
          end
        Config.logger.debug { regular_query_message(time / TICKS_PER_MICROSECOND, _query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, _query, args)
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, _query, args)
      end

      def scalar(_query, args = [] of DB::Any)
        time = Time.now.ticks
        res = with_connection { |conn| args.empty? ? conn.scalar(_query) : conn.scalar(_query, args) }
        time = Time.now.ticks - time
        Config.logger.debug { regular_query_message(time / TICKS_PER_MICROSECOND, _query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, _query, args)
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, _query, args)
      end

      def parse_query(q, args)
        SqlGenerator.parse_query(q, args.size)
      end

      def parse_query(q)
        SqlGenerator.parse_query(q)
      end
    end
  end
end
