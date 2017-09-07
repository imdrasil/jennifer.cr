require "./expression_builder"

module Jennifer
  module QueryBuilder
    class Query
      extend Ifrit

      {% for method in %i(having table limit offset raw_select table_aliases from lock joins order relations group lock unions) %}
        def _{{method.id}}
          @{{method.id}}
        end
      {% end %}

      @having : Condition | LogicOperator | Nil
      @table : String = ""
      @limit : Int32?
      @offset : Int32?
      @raw_select : String?
      @from : String | Query?
      @lock : String | Bool?

      property tree : Condition | LogicOperator?

      def initialize
        @do_nothing = false
        @expression = ExpressionBuilder.new(@table)
        @joins = [] of Join
        @order = {} of String => String
        @relations = [] of String
        @group = {} of String => Array(String)
        @relation_used = false
        @table_aliases = {} of String => String
        @unions = [] of Query
      end

      def initialize(@table)
        initialize
      end

      def self.build(*opts)
        q = new(*opts)
        q.expression_builder.query = q
        q
      end

      def self.[](*opts)
        build(*opts)
      end

      def to_sql
        Adapter::SqlGenerator.select(self)
      end

      def as_sql
        @tree ? @tree.not_nil!.as_sql : ""
      end

      def sql_args
        if @tree
          @tree.not_nil!.sql_args
        else
          [] of DB::Any
        end
      end

      def sql_args_count
        @tree ? @tree.not_nil!.sql_args_count : 0
      end

      def select_args
        args = [] of DB::Any
        args.concat(@from.as(Query).select_args) if @from.is_a?(Query)
        @joins.each do |join|
          args.concat(join.sql_args)
        end
        args.concat(@tree.not_nil!.sql_args) if @tree
        args.concat(@having.not_nil!.sql_args) if @having
        args
      end

      def select_args_count
        count = 0
        count += @from.as(Query).select_args_count if @from.is_a?(Query)
        @joins.each do |join|
          count += join.sql_args_count
        end
        count += @tree.not_nil!.sql_args_count if @tree
        count += @having.not_nil!.sql_args_count if @having
        count
      end

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
        other = (with @expression yield)
        set_tree(other)
        self
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

      def from(_from)
        @from = _from
        self
      end

      def none
        @do_nothing = true
        self
      end

      def having
        other = with @expression yield
        @having = other
        self
      end

      def union(query)
        @unions << query
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
        raise RecordNotFound.new(Adapter::SqlGenerator.select(self)) if result.empty?
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
        result = to_a
        @limit = old_limit
        raise RecordNotFound.new(Adapter::SqlGenerator.select(self)) if result.empty?
        result[0]
      end

      def pluck(fields : Array)
        ::Jennifer::Adapter.adapter.pluck(self, fields.map(&.to_s))
      end

      def pluck(field)
        ::Jennifer::Adapter.adapter.pluck(self, field.to_s)
      end

      def pluck(*fields)
        ::Jennifer::Adapter.adapter.pluck(self, fields.to_a.map(&.to_s))
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

      def group(column)
        arr = _groups(table)
        arr << column.to_s
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

      # skips any callbacks and validations
      def increment(fields : Hash)
        hash = {} of Symbol | String => NamedTuple(value: DBAny, operator: Symbol)
        fields.each do |k, v|
          hash[k] = {value: v, operator: :+}
        end
        modify(hash)
      end

      # skips any callbacks and validations
      def increment(**fields)
        hash = {} of Symbol | String => NamedTuple(value: DBAny, operator: Symbol)
        fields.each do |k, v|
          hash[k] = {value: v, operator: :+}
        end
        modify(hash)
      end

      # skips any callbacks and validations
      def decrement(fields : Hash)
        hash = {} of Symbol | String => NamedTuple(value: DBAny, operator: Symbol)
        fields.each do |k, v|
          hash[k] = {value: v, operator: :-}
        end
        modify(hash)
      end

      # skips any callbacks and validations
      def decrement(**fields)
        hash = {} of Symbol | String => NamedTuple(value: DBAny, operator: Symbol)
        fields.each do |k, v|
          hash[k] = {value: v, operator: :-}
        end
        modify(hash)
      end

      # skips any callbacks and validations
      def modify(options : Hash)
        ::Jennifer::Adapter.adapter.modify(self, options)
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

      def max(field, klass : T.class) : T forall T
        raise ArgumentError.new("Cannot use with grouping") unless @group.empty?
        group_max(field, klass)[0]
      end

      def min(field, klass : T.class) : T forall T
        raise ArgumentError.new("Cannot use with grouping") unless @group.empty?
        group_min(field, klass)[0]
      end

      def sum(field, klass : T.class) : T forall T
        raise ArgumentError.new("Cannot use with grouping") unless @group.empty?
        group_sum(field, klass)[0]
      end

      def avg(field, klass : T.class) : T forall T
        raise ArgumentError.new("Cannot use with grouping") unless @group.empty?
        group_avg(field, klass)[0]
      end

      def group_max(field, klass : T.class) : Array(T) forall T
        _select = @raw_select
        @raw_select = "MAX(#{field}) as m"
        result = to_a.map(&.["m"])
        @raw_select = _select
        typed_array_cast(result, T)
      end

      def group_min(field, klass : T.class) : Array(T) forall T
        _select = @raw_select
        @raw_select = "MIN(#{field}) as m"
        result = to_a.map(&.["m"])
        @raw_select = _select
        typed_array_cast(result, T)
      end

      def group_sum(field, klass : T.class) : Array(T) forall T
        _select = @raw_select
        @raw_select = "SUM(#{field}) as m"
        result = to_a.map(&.["m"])
        @raw_select = _select
        typed_array_cast(result, T)
      end

      def group_avg(field, klass : T.class) : Array(T) forall T
        _select = @raw_select
        @raw_select = "AVG(#{field}) as m"
        result = to_a.map(&.["m"])
        @raw_select = _select
        typed_array_cast(result, T)
      end

      def group_count(field)
        _select = @raw_select
        @raw_select = "COUNT(#{field}) as m"
        result = to_a.map(&.["m"])
        @raw_select = _select
        result
      end

      def lock(type = true)
        @lock = type
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

      def set_tree(other : LogicOperator | Condition)
        @tree = if !@tree.nil? && !other.nil?
                  @tree.as(Condition | LogicOperator) & other
                else
                  other
                end
        self
      end

      def set_tree(other : Query)
        set_tree(other.tree)
      end

      def set_tree(other : Criteria)
        set_tree(Condition.new(other))
      end

      def set_tree(other : Nil)
        raise ArgumentError.new("Condition tree couldn't be nil")
      end

      def to_a
        results
      end

      def db_results
        result = [] of Hash(String, DBAny)
        return result if @do_nothing
        each_result_set do |rs|
          result << Adapter.adapter.result_to_hash(rs)
        end
        result
      end

      def results
        result = [] of Record
        return result if @do_nothing
        each_result_set { |rs| result << Record.new(rs) }
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

      private def find_with_nested
      end
    end
  end
end
