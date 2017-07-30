module Jennifer
  module QueryBuilder
    module SQLGenerationMethods
      def to_sql
        if @tree
          @tree.not_nil!.to_sql
        else
          ""
        end
      end

      def sql_args
        if @tree
          @tree.not_nil!.sql_args
        else
          [] of DB::Any
        end
      end

      def select_query(fields = [] of String)
        select_clause(fields) + body_section
      end

      def group_clause
        if @group.empty?
          ""
        else
          fields = @group.map { |t, fields| fields.map { |f| "#{t}.#{f}" }.join(", ") }.join(", ") # TODO: make building better
          "GROUP BY #{fields}\n"
        end
      end

      def having_clause
        return "" unless @having
        "HAVING #{@having.not_nil!.to_sql}\n"
      end

      def select_clause(exact_fields = [] of String)
        String.build do |s|
          s << "SELECT "
          unless @raw_select
            if exact_fields.size > 0
              exact_fields.map { |f| "#{table}.#{f}" }.join(", ", s)
            else
              s << table << ".*"
            end
          else
            s << @raw_select
          end
          s << "\n"
          from_clause(s)
        end
      end

      def from_clause(io)
        io << "FROM "
        return io << table << "\n" unless @from
        io << "( " <<
          if @from.is_a?(String)
            @from
          else
            @from.as(Query).select_query
          end
        io << " ) "
      end

      def body_section
        String.build do |s|
          s << join_clause << where_clause
          order_clause(s)
          s << limit_clause << group_clause << having_clause
        end
      end

      def join_clause
        @joins.map(&.to_sql).join(' ')
      end

      def where_clause
        @tree ? "WHERE #{@tree.not_nil!.to_sql}\n" : ""
      end

      def limit_clause
        str = ""
        str += "LIMIT #{@limit}\n" if @limit
        str += "OFFSET #{@offset}\n" if @offset
        str
      end

      def order_clause(io)
        return if @order.empty?
        io << "ORDER BY "
        @order.each_with_index do |(k, v), i|
          io << ", " if i > 0
          io << k << " " << v.upcase
        end
        io << "\n"
      end

      def select_args
        args = [] of DB::Any
        args.concat(@from.as(Query).select_args) if @from.is_a?(Query)
        @joins.each do |join|
          args += join.sql_args
        end
        args += @tree.not_nil!.sql_args if @tree
        args += @having.not_nil!.sql_args if @having
        args
      end
    end
  end
end
