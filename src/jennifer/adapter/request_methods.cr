module Jennifer
  module Adapter
    # Badly named module including high level method to interact with db
    module RequestMethods
      def insert(table, opts : Hash)
        exec SqlGenerator.insert(table, opts)
      end

      def insert(obj : Model::Base)
        exec SqlGenerator.insert(obj)
      end

      def update(obj : Model::Base)
        opts = obj.arguments_to_save
        return DB::ExecResult.new(0i64, -1i64) if opts[:args].empty?
        # opts[:args] << obj.primary
        exec SqlGenerator.update(obj)
      end

      def update(query, options : Hash)
        # args = [] of DBAny
        # options.each do |k, v|
        #   args << v
        # end
        # args.concat(query.select_args)
        # exec(parse_query(SqlGenerator.update(query, options), args), args)
        exec(SqlGenerator.update(query, options))
      end

      def modify(q, modifications : Hash)
        query = SqlGenerator.modify(q, modifications)
        # args = [] of DBAny
        # modifications.each do |k, v|
        #   args << v[:value]
        # end
        # args.concat(q.select_args)
        # exec(parse_query(query, args), args)
        exec(query)
      end

      def distinct(query : QueryBuilder::ModelQuery, column, table)
        str = SqlGenerator.select_distinct(query, column, table)
        # args = query.select_args
        result = [] of DBAny
        # query(parse_query(str, args), args) do |rs|
        query(str) do |rs|
          rs.each do
            result << result_to_array(rs)[0]
          end
        end
        result
      end

      def pluck(query, fields : Array)
        result = [] of Array(DBAny)
        body = SqlGenerator.select(query, fields)
        # args = query.select_args
        # query(parse_query(body, args), args) do |rs|
        query(body) do |rs|
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
        # args = query.select_args
        # query(parse_query(body, args), args) do |rs|
        query(body) do |rs|
          rs.each do
            result << result_to_array_by_names(rs, fields)[0]
          end
        end
        result
      end

      def select(q)
        body = SqlGenerator.select(q)
        # args = q.select_args
        # query(parse_query(body, args), args) { |rs| yield rs }
        query(body) { |rs| yield rs }
      end
    end
  end
end
