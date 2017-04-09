require "./expression_builder"

module Jennifer
  module QueryBuilder
    abstract class IQuery
      @having : Criteria | LogicOperator | Nil
      @table : String = ""
      @limit : Int32?
      @offset : Int32?
      @raw_select : String?
      @table_aliases = {} of String => String

      property tree : Criteria | LogicOperator?

      def initialize
        @expression = ExpressionBuilder.new(@table)
        @joins = [] of Join
        @order = {} of String => String
        @relations = [] of String
        @group = {} of String => Array(String)
        @relation_used = false
      end

      def self.build(*opts)
        q = new(*opts)
        q.expression_builder.query = q
        q
      end

      def initialize(@table)
        initialize
      end

      {% for attr in [:having, :limit, :offset, :raw_select, :table_aliases, :joins, :order, :relations, :group] %}
        protected def {{attr.id}}
          @{{attr.id}}
        end
      {% end %}

      def with_relation!
        @relation_used = true
      end

      def with_relation?
        @relation_used
      end

      def expression_builder
        @expression
      end

      def table
        @table
      end

      def empty?
        @tree.nil? && @limit.nil? && @offset.nil? &&
          @joins.empty? && @order.empty? && @relations.empty?
      end

      def to_s
        (@tree || "").to_s
      end

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

      def set_tree(other : Criteria | LogicOperator | IQuery)
        other = other.tree if other.is_a? IQuery
        @tree = if !@tree.nil? && !other.nil?
                  @tree.as(Criteria | LogicOperator) & other
                else
                  other
                end
        self
      end

      def set_tree(other : Nil)
        raise ArgumentError.new("Condition tree couldn't be nil")
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
              unless @relations.empty?
                s << ", "
                @relations.each_with_index do |r, i|
                  s << ", " if i != 0
                  s << (@table_aliases[r]? || model_class.relations[r].table_name) << ".*"
                end
              end
            end
          else
            s << @raw_select
          end
          s << "\n"
          from_clause(s)
        end
      end

      def from_clause(io)
        io << "FROM " << table << "\n"
      end

      def body_section
        String.build do |s|
          s << where_clause << join_clause
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
        args += @tree.not_nil!.sql_args if @tree
        @joins.each do |join|
          args += join.sql_args
        end
        args += @having.not_nil!.sql_args if @having
        args
      end

      abstract def model_class
    end
  end
end
