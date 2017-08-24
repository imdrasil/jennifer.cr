module Jennifer
  module Adapter
    module RequestMethods
      # query ===========================

      def insert(table, opts : Hash)
        values = opts.values
        exec parse_query(SqlGenerator.insert(table, opts), values), values
      end

      def insert(obj : Model::Base)
        opts = obj.arguments_to_insert
        exec parse_query(SqlGenerator.insert(obj), opts[:args]), opts[:args]
      end

      def update(obj : Model::Base)
        opts = obj.arguments_to_save
        return DB::ExecResult.new(0i64, -1i64) if opts[:args].empty?
        opts[:args] << obj.primary
        exec(parse_query(SqlGenerator.update(obj), opts[:args]), opts[:args])
      end

      def update(query, options : Hash)
        args = [] of DBAny
        options.each do |k, v|
          args << v
        end
        args.concat(query.select_args)
        exec(parse_query(SqlGenerator.update(query, options), args), args)
      end

      def modify(q, modifications : Hash)
        query = SqlGenerator.modify(q, modifications)
        args = [] of DBAny
        modifications.each do |k, v|
          args << v[:value]
        end
        args.concat(q.select_args)
        exec(parse_query(query, args), args)
      end

      def distinct(query : QueryBuilder::ModelQuery, column, table)
        str = SqlGenerator.select_distinct(query, column, table)
        args = query.select_args
        result = [] of DBAny
        query(parse_query(str, args), args) do |rs|
          rs.each do
            result << result_to_array(rs)[0]
          end
        end
        result
      end

      def pluck(query, fields : Array)
        result = [] of Array(DBAny)
        body = SqlGenerator.select(query, fields)
        args = query.select_args
        query(parse_query(body, args), args) do |rs|
          rs.each do
            result << result_to_array_by_names(rs, fields)
          end
        end
        result
      end

      def pluck(query, field)
        result = [] of DBAny
        fields = [field.to_s]
        body = SqlGenerator.select(query, fields)
        args = query.select_args
        query(parse_query(body, args), args) do |rs|
          rs.each do
            result << result_to_array_by_names(rs, fields)[0]
          end
        end
        result
      end

      def select(q)
        body = SqlGenerator.select(q)
        args = q.select_args
        query(parse_query(body, args), args) { |rs| yield rs }
      end
    end
  end
end
