require "./expression_builder"
require "./aggregations"

module Jennifer
  module QueryBuilder
    class Query
      extend Ifrit
      include Aggregations

      {% for method in %i(having table limit offset raw_select table_aliases from lock joins order relations groups lock unions) %}
        def _{{method.id}}
          @{{method.id}}
        end

        def _{{method.id}}!
          @{{method.id}}.not_nil!
        end
      {% end %}

      @having : Condition | LogicOperator | Nil
      @table : String = ""
      @limit : Int32?
      @offset : Int32?
      @raw_select : String?
      @from : String | Query?
      @lock : String | Bool?
      @joins : Array(Join)?
      @unions : Array(Query)?

      def_clone

      property tree : Condition | LogicOperator?
      getter table

      def initialize
        @do_nothing = false
        @expression = ExpressionBuilder.new(@table)
        @order = {} of Criteria => String
        @relations = [] of String
        @groups = [] of Criteria
        @relation_used = false
        @table_aliases = {} of String => String
        @select_fields = [] of Criteria
      end

      def initialize(@table)
        initialize
      end

      def expression_builder
        @expression
      end

      def _select_fields : Array(Criteria)
        if @select_fields.empty?
          b = [] of Criteria
          b << @expression.star
          b
        else
          @select_fields
        end
      end

      protected def add_join(value : Join)
        @joins ||= [] of Join
        @joins.not_nil! << value
      end

      protected def add_union(value : Query)
        @unions ||= [] of Query
        @unions.not_nil! << value
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
        _joins!.each { |join| args.concat(join.sql_args) } if @joins
        args.concat(@tree.not_nil!.sql_args) if @tree
        args.concat(@having.not_nil!.sql_args) if @having
        args
      end

      def select_args_count
        count = 0
        count += @from.as(Query).select_args_count if @from.is_a?(Query)
        _joins!.each { |join| count += join.sql_args_count } if @joins
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

      def empty?
        @tree.nil? && @limit.nil? && @offset.nil? &&
          (@joins.nil? || @joins.not_nil!.empty?) && @order.empty? && @relations.empty?
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
        add_join(Join.new(klass.table_name, other, type, relation: relation))
        self
      end

      def join(_table : String, aliass : String? = nil, type = :inner, relation : String? = nil)
        eb = ExpressionBuilder.new(_table, relation, self)
        with_relation! if relation
        other = with eb yield eb
        add_join(Join.new(_table, other, type, relation))
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

      def select(field : Criteria)
        @select_fields << field
        field.as(RawSql).without_brackets if field.is_a?(RawSql)
        self
      end

      def select(field_name : Symbol)
        @select_fields << @expression.c(field_name.to_s)
        self
      end

      def select(*fields : Symbol)
        fields.each { |f| @select_fields << @expression.c(f.to_s) }
        self
      end

      def select(fields : Array(Criteria))
        fields.each do |f|
          @select_fields << f
          f.as(RawSql).without_brackets if f.is_a?(RawSql)
        end
        self
      end

      def select(&block)
        fields = with @expression yield
        fields.each do |f|
          f.as(RawSql).without_brackets if f.is_a?(RawSql)
        end
        @select_fields.concat(fields)
        self
      end

      def from(_from : String | Query)
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
        add_union(query)
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

      def pluck(field : String | Symbol)
        ::Jennifer::Adapter.adapter.pluck(self, field.to_s)
      end

      def pluck(*fields : String | Symbol)
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

      def distinct(column : String, _table : String)
        ::Jennifer::Adapter.adapter.distinct(self, column, _table)
      end

      def distinct(column : String)
        ::Jennifer::Adapter.adapter.distinct(self, column, table)
      end

      # Groups by given column realizes it as is
      def group(column : String)
        @groups << @expression.sql(column, false)
        self
      end

      # Groups by given column realizes it as current table's field
      def group(column : Symbol)
        @groups << @expression.c(column.to_s)
        self
      end

      # Groups by given columns realizes them as are
      def group(*columns : String)
        columns.each { |c| @groups << @expression.sql(c, false) }
        self
      end

      # Groups by given columns realizes them as current table's ones
      def group(*columns : Symbol)
        columns.each { |c| @groups << @expression.c(c.to_s) }
        self
      end

      def group(column : Criteria)
        column.as(RawSql).without_brackets if column.is_a?(RawSql)
        @groups << column
        self
      end

      def group(&block)
        fields = with @expression yield
        fields.each { |f| f.as(RawSql).without_brackets if f.is_a?(RawSql) }
        @groups.concat(fields)
        self
      end

      def limit(count : Int32)
        @limit = count
        self
      end

      def offset(count : Int32)
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

      def order(opts : Hash(String, String | Symbol))
        opts.each do |k, v|
          @order[@expression.sql(k, false)] = v.to_s
        end
        self
      end

      def order(opts : Hash(Symbol, String | Symbol))
        opts.each do |k, v|
          @order[@expression.c(k.to_s)] = v.to_s
        end
        self
      end

      def order(opts : Hash(Criteria, String | Symbol))
        opts.each do |k, v|
          @order[k] = v.to_s
          k.as(RawSql).without_brackets if k.is_a?(RawSql)
        end
        self
      end

      def order(&block)
        order(with @expression yield)
      end

      def lock(type : String | Bool = true)
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
          begin
            rs.each do
              yield rs
            end
          rescue e : Exception
            rs.read_to_end
            raise e
          end
        end
      end

      def find_batch(batch_size : Int32 = 1000)
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
          @order[@expression.c("id")] = "DESC"
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

      private def _groups(name : String)
        @group[name] ||= [] of String
      end

      private def find_with_nested
      end
    end
  end
end
