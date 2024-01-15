module Jennifer
  module Adapter
    module RequestMethods
      def insert(table, opts : Hash)
        values = opts.values
        exec(*parse_query(sql_generator.insert(table, opts), values))
      end

      def insert(obj : Model::Base)
        opts = obj.arguments_to_insert
        exec(*parse_query(sql_generator.insert(obj), opts[:args]))
      end

      def update(obj : Model::Base)
        return DB::ExecResult.new(0i64, -1i64) unless obj.changed?

        opts = obj.arguments_to_save
        opts[:args] << obj.primary
        exec(*parse_query(sql_generator.update(obj), opts[:args]))
      end

      def update(query, options : Hash)
        args = [] of DBAny
        options.each { |_, v| args << v }
        args.concat(query.sql_args)
        exec(*parse_query(sql_generator.update(query, options), args))
      end

      def modify(q, modifications : Hash)
        query = sql_generator.modify(q, modifications)
        args = [] of DBAny
        modifications.each do |_, v|
          add_field_assign_arguments(args, v)
        end
        args.concat(q.sql_args)
        exec(*parse_query(query, args))
      end

      def pluck(query, fields : Array)
        result = [] of Array(DBAny)
        body = sql_generator.select(query, fields)
        args = query.sql_args
        query(*parse_query(body, args)) do |rs|
          rs.each do
            result << result_to_array_by_names(rs, fields)
          end
        end
        result
      end

      def pluck(query, field : String | Symbol)
        result = [] of DBAny
        fields = [field.to_s]
        body = sql_generator.select(query, fields)
        args = query.sql_args
        query(*parse_query(body, args)) do |rs|
          rs.each do
            result << result_to_array_by_names(rs, fields)[0]
          end
        end
        result
      end

      def select(q, &)
        body = sql_generator.select(q)
        args = q.sql_args
        query(*parse_query(body, args)) { |rs| yield rs }
      end

      private def add_field_assign_arguments(container : Array, value : DBAny)
        container << value
      end

      private def add_field_assign_arguments(container : Array, value : QueryBuilder::Statement)
        container.concat(value.sql_args)
      end
    end
  end
end
