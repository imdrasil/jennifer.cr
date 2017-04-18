require "./expression_builder"

module Jennifer
  module QueryBuilder
    class PlainQuery
      @having : Condition | LogicOperator | Nil
      @table : String = ""
      @limit : Int32?
      @offset : Int32?
      @raw_select : String?
      @table_aliases = {} of String => String

      property tree : Condition | LogicOperator?

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

      def exec(&block)
        with self yield
        self
      end

      def where(&block)
        other = with @expression yield
        set_tree(other)
      end

      def join(klass : Class, aliass : String? = nil, type = :inner, relation : String? = nil)
        eb = ExpressionBuilder.new(klass.table_name, relation, self)
        with_relation! if relation
        other = with eb yield eb
        @joins << Join.new(klass.table_name, other, type, relation: relation)
        self
      end

      def join(_table : String, aliass : String? = nil, type = :inner, relation : String? = nil)
        eb = ExpressionBuilder.new(_table, relation, self)
        with_relation! if relation
        other = with eb yield eb
        @joins << Join.new(_table, other, type, relation)
        self
      end

      def left_join(klass : Class, aliass : String? = nil)
        join(klass, aliass, :left) { |eb| with eb yield }
      end

      def left_join(_table : String, aliass : String? = nil)
        join(_table, aliass, :left) { |eb| with eb yield }
      end

      def right_join(klass : Class, aliass : String? = nil)
        join(klass, aliass, :right) { |eb| with eb yield }
      end

      def right_join(_table : String)
        join(_table, aliass, :left) { |eb| with eb yield }
      end

      def select(raw_sql : String)
        @raw_select = raw_sql
        self
      end

      def having
        other = with @expression yield
        @having = other
        self
      end

      def last
        reverse_order
        old_limit = @limit
        @limit = 1
        r = to_a[0]?
        @limit = old_limit
        reverse_order
        r
      end

      def last!
        old_limit = @limit
        @limit = 1
        reverse_order
        result = to_a
        reverse_order
        @limit = old_limit
        raise RecordNotFound.new(self.select_query) if result.empty?
        result[0]
      end

      def first
        old_limit = @limit
        @limit = 1
        r = to_a[0]?
        @limit = old_limit
        r
      end

      def first!
        old_limit = @limit
        @limit = 1
        result = to_a
        @limit = old_limit
        raise RecordNotFound.new(self.select_query) if result.empty?
        result[0]
      end

      def pluck(field)
        ::Jennifer::Adapter.adapter.pluck(self, field.to_s)
      end

      def pluck(*fields)
        ::Jennifer::Adapter.adapter.pluck(self, fields.to_a.map(&.to_s))
      end

      # def pluck(**fields)
      #  hash = fields.to_h
      #  result = [] of Hash(String, DB::Any | Int16 | Int8)
      #  ::Jennifer::Adapter.adapter.query(select_query, select_args) do |rs|
      #    rs.each do
      #      h = {} of String => DB::Any | Int8 | Int16
      #      res_hash = ::Jennifer::Adapter.adapter_class.result_to_hash(rs)
      #      fields.each do |k, v|
      #        h[k.to_s] = res_hash[k.to_s]
      #      end
      #      result << h
      #    end
      #  end
      #  result
      # end

      def destroy
        delete
      end

      def delete
        ::Jennifer::Adapter.adapter.delete(self)
      end

      def exists?
        ::Jennifer::Adapter.adapter.exists?(self)
      end

      def count : Int32
        ::Jennifer::Adapter.adapter.count(self)
      end

      def distinct(column, _table)
        ::Jennifer::Adapter.adapter.distinct(self, column, _table)
      end

      def distinct(column : String)
        ::Jennifer::Adapter.adapter.distinct(self, column, table)
      end

      def group(column : String)
        arr = _groups(table)
        arr << column
        self
      end

      def group(*columns)
        _groups(table).concat(columns.to_a)
        self
      end

      def group(**columns)
        columns.each do |t, fields|
          _groups(t.to_s).concat(fields)
        end
        self
      end

      def limit(count)
        @limit = count
        self
      end

      def offset(count)
        @offset = count
        self
      end

      def update(options : Hash)
        ::Jennifer::Adapter.adapter.update(self, options)
      end

      def update(**options)
        update(options.to_h)
      end

      def order(**opts)
        order(opts.to_h)
      end

      def order(opts : Hash(String | Symbol, String | Symbol))
        opts.each do |k, v|
          @order[k.to_s] = v.to_s
        end
        self
      end

      def each
        to_a.each do |e|
          yield e
        end
      end

      def each_result_set(&block)
        ::Jennifer::Adapter.adapter.select(self) do |rs|
          rs.each do
            yield rs
          end
        end
      end

      def find_batch(batch_size = 1000)
        raise "Not implemented"
      end

      # works only if there is id field and it is covertable to Int32
      def ids
        pluck(:id).map(&.to_i)
      end

      def to_s
        to_sql
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

      def set_tree(other : LogicOperator | Condition)
        @tree = if !@tree.nil? && !other.nil?
                  @tree.as(Condition | LogicOperator) & other
                else
                  other
                end
        self
      end

      def set_tree(other : PlainQuery)
        set_tree(other.tree)
      end

      def set_tree(other : Criteria)
        set_tree(Condition.new(other))
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
        @joins.each do |join|
          args += join.sql_args
        end
        args += @tree.not_nil!.sql_args if @tree
        args += @having.not_nil!.sql_args if @having
        args
      end

      def to_a
        result = [] of Hash(String, DBAny)
        Adapter.adapter.select(self) do |rs|
          rs.each do
            result << Adapter.adapter.result_to_hash(rs)
          end
        end
        result
      end

      #
      # private methods
      #

      private def reverse_order
        if @order.empty?
          @order["id"] = "DESC"
        else
          @order.each do |k, v|
            @order[k] =
              case v
              when "asc", "ASC"
                "DESC"
              else
                "ASC"
              end
          end
        end
      end

      private def _groups(name)
        @group[name] ||= [] of String
      end
    end
  end
end
