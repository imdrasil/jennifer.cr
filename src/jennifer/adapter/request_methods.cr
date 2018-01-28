module Jennifer
  module Adapter
    module RequestMethods
      # query ===========================

      def insert(table, opts : Hash)
        values = opts.values
        exec *parse_query(sql_generator.insert(table, opts), values)
      end

      def insert(obj : Model::Base)
        opts = obj.arguments_to_insert
        exec *parse_query(sql_generator.insert(obj), opts[:args])
      end

      def update(obj : Model::Base)
        opts = obj.arguments_to_save
        return DB::ExecResult.new(0i64, -1i64) if opts[:args].empty?
        opts[:args] << obj.primary
        exec(*parse_query(sql_generator.update(obj), opts[:args]))
      end

      def update(query, options : Hash)
        args = [] of DBAny
        options.each do |k, v|
          args << v
        end
        args.concat(query.select_args)
        exec(*parse_query(sql_generator.update(query, options), args))
      end

      def modify(q, modifications : Hash)
        query = sql_generator.modify(q, modifications)
        args = [] of DBAny
        modifications.each do |k, v|
          args << v[:value]
        end
        args.concat(q.select_args)
        exec(*parse_query(query, args))
      end

      def pluck(query, fields : Array)
        result = [] of Array(DBAny)
        body = sql_generator.select(query, fields)
        args = query.select_args
        query(*parse_query(body, args)) do |rs|
          rs.each do
            result << result_to_array_by_names(rs, fields)
          end
        end
        result
      end

      def pluck(query, field)
        result = [] of DBAny
        fields = [field.to_s]
        body = sql_generator.select(query, fields)
        args = query.select_args
        query(*parse_query(body, args)) do |rs|
          rs.each do
            result << result_to_array_by_names(rs, fields)[0]
          end
        end
        result
      end

      def select(q)
        body = sql_generator.select(q)
        args = q.select_args
        query(*parse_query(body, args)) { |rs| yield rs }
      end
    end
  end
end
