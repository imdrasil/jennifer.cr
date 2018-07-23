require "./expression_builder"
require "./aggregations"
require "./ordering"
require "./joining"
require "./executables"

module Jennifer
  module QueryBuilder
    class Query
      extend Ifrit
      include Aggregations
      include Ordering
      include Joining
      include Executables

      {% for method in %i(having table limit offset raw_select table_aliases from lock joins order relations groups lock unions distinct) %}
        def _{{method.id}}
          @{{method.id}}
        end

        def _{{method.id}}!
          @{{method.id}}.not_nil!
        end
      {% end %}

      getter table : String = ""

      @having : Condition | LogicOperator?
      @limit : Int32?
      @distinct : Bool = false
      @offset : Int32?
      @raw_select : String?
      @from : String | Query?
      @lock : String | Bool?
      @joins : Array(Join)?
      @unions : Array(Query)?

      def_clone

      property tree : Condition | LogicOperator?

      def initialize
        @do_nothing = false
        @expression = ExpressionBuilder.new(@table)
        @order = CriteriaContainer.new
        @relations = [] of String
        @groups = [] of Criteria
        @relation_used = false
        @table_aliases = {} of String => String
        @select_fields = [] of Criteria
      end

      def initialize(@table)
        initialize
      end

      protected def initialize_copy_without(other, except : Array(String))
        {% for segment in %w(having limit offset raw_select from lock distinct) %}
          @{{segment.id}} = other.@{{segment.id}}.clone unless except.includes?({{segment}})
        {% end %}

        @order = except.includes?("order") ? CriteriaContainer.new : other.@order.clone
        @joins = other.@joins.clone unless except.includes?("join")
        @unions = other.@unions.clone unless except.includes?("union")
        @groups = except.includes?("group") ? [] of Criteria : other.@groups.clone
        @do_nothing = except.includes?("none") ? false : other.@do_nothing
        @select_fields = except.includes?("select") ? [] of Criteria : other.@select_fields
        @tree = other.@tree.clone unless except.includes?("where")

        @table = other.@table.clone
        @table_aliases = other.@table_aliases.clone

        @relation_used = false
        @relations = [] of String
        @expression = ExpressionBuilder.new(@table)
      end

      # Compare current object with given comparing generated sql query and parameters.
      # Is mostly used for testing
      def eql?(other : Query)
        sql_args == other.sql_args && to_sql == other.to_sql
      end

      def clone
        clone = {{@type}}.allocate
        clone.initialize_copy(self)
        clone.expression_builder.query = clone
        clone
      end

      def except(parts : Array(String))
        clone = {{@type}}.allocate
        clone.initialize_copy_without(self, parts)
        clone.expression_builder.query = clone
        clone
      end

      def expression_builder
        @expression
      end

      # Returns array of `Criteria` for `SELECT` query statement.
      def _select_fields : Array(Criteria)
        if @select_fields.empty?
          [@expression.star] of Criteria
        else
          @select_fields
        end
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
        adapter.sql_generator.select(self)
      end

      def as_sql
        @tree ? @tree.not_nil!.as_sql(adapter.sql_generator) : ""
      end

      def as_sql(_generator)
        @tree ? @tree.not_nil!.as_sql(adapter.sql_generator) : ""
      end

      def sql_args
        @tree ? @tree.not_nil!.sql_args : [] of DBAny
      end

      # Returns array of query arguments.
      def select_args
        args = [] of DBAny
        args.concat(select_filterable_arguments) if select_filterable_arguments?
        args.concat(@from.as(Query).select_args) if @from.is_a?(Query)
        _joins!.each { |join| args.concat(join.sql_args) } if @joins
        args.concat(@tree.not_nil!.sql_args) if @tree
        args.concat(@having.not_nil!.sql_args) if @having
        args
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
        if @having.nil?
          @having = other
        else
          @having = @having.not_nil! & other
        end
        self
      end

      def union(query)
        add_union(query)
        self
      end

      def distinct
        @distinct = true
        self
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

      def lock(type : String | Bool = true)
        @lock = type
        self
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
        raise ArgumentError.new("Condition tree can't be blank.")
      end

      def filterable?
        select_filterable_arguments? ||
          (@from.is_a?(Query) && @from.as(Query).filterable?) ||
          (!@joins.nil? && _joins!.any?(&.filterable?)) ||
          (!@tree.nil? && @tree.not_nil!.filterable?) ||
          (!@having.nil? && @having.not_nil!.filterable?)
      end

      #
      # private methods
      #

      private def select_filterable_arguments?
        @select_fields.any?(&.filterable?)
      end

      private def select_filterable_arguments
        args = [] of DBAny
        @select_fields.each do |field|
          args.concat(field.sql_args) if field.filterable?
        end
        args
      end

      private def _groups(name : String)
        @group[name] ||= [] of String
      end

      private def adapter
        Adapter.default_adapter
      end
    end
  end

  alias Query = QueryBuilder::Query
end
