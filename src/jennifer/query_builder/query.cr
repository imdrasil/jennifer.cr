require "./aggregations"
require "./ordering"
require "./joining"
require "./executables"

module Jennifer
  module QueryBuilder
    class Query
      include Statement
      include Aggregations
      include Ordering
      include Joining
      include Executables

      alias UnionType = NamedTuple(query: Query, all: Bool)

      {% for method in %i(having table limit offset raw_select table_aliases from lock distinct) %}
        # :nodoc:
        def _{{method.id}}
          @{{method.id}}
        end

        # :nodoc:
        def _{{method.id}}?
          @{{method.id}}
        end

        # :nodoc:
        def _{{method.id}}!
          @{{method.id}}.not_nil!
        end
      {% end %}

      {% for method in %i(groups joins unions order ctes) %}
        # :nodoc:
        def _{{method.id}}?
          @{{method.id}}
        end
      {% end %}

      # Table name to be specified in `FROM` clause.
      getter table : String = ""

      getter adapter : Adapter::Base

      @having : Condition | LogicOperator?
      @limit : Int32?
      @distinct : Bool = false
      @offset : Int32 | Int64 | Nil
      @raw_select : String?
      @from : String | Query?
      @lock : String | Bool?
      @joins : Array(Join)?
      @unions : Array(UnionType)?
      @groups : Array(Criteria)?
      @order : Array(OrderExpression)?
      @select_fields : Array(Criteria)?
      @ctes : Array(CommonTableExpression)?
      @do_nothing = false
      @relation_used = false
      @table_aliases = {} of String => String

      # Query filter to be rendered in `WHERE` clause.
      property tree : Condition | LogicOperator?

      def initialize
        @expression = ExpressionBuilder.new(@table)
        @adapter = Adapter.default_adapter
      end

      def initialize(@table, @adapter = Adapter.default_adapter)
        @expression = ExpressionBuilder.new(@table)
      end

      def clone
        clone = {{@type}}.allocate
        clone.initialize_copy(self)
        clone
      end

      protected def initialize_copy(other)
        @table = other.@table
        @adapter = other.@adapter
        @having = other.@having.clone
        @limit = other.@limit
        @distinct = other.@distinct
        @offset = other.@offset
        @raw_select = other.@raw_select
        @from = other.@from.clone
        @lock = other.@lock
        @joins = other.@joins.clone
        @unions = other.@unions.clone
        @groups = other.@groups.clone
        @order = other.@order.clone
        @select_fields = other.@select_fields.clone
        @ctes = other.@ctes.clone
        @do_nothing = other.@do_nothing
        @relation_used = other.@relation_used
        @table_aliases = other.@table_aliases.clone
        @tree = other.@tree.clone
        @expression = other.@expression.clone
      end

      # :nodoc:
      def _select_fields!
        @select_fields ||= [] of Criteria
      end

      # :nodoc:
      def _groups!
        @groups ||= [] of Criteria
      end

      # :nodoc:
      def _joins!
        @joins ||= [] of Join
      end

      # :nodoc:
      def _unions!
        @unions ||= [] of UnionType
      end

      # :nodoc:
      def _order!
        @order ||= [] of OrderExpression
      end

      # :nodoc:
      def _ctes!
        @ctes ||= [] of CommonTableExpression
      end

      # Alias for `new(table).none`.
      def self.null(table = "")
        new(table).none
      end

      # Returns whether query should be executed.
      def do_nothing?
        @do_nothing
      end

      protected def initialize_copy_without(other, except : Array(String))
        {% for segment in %w(having limit offset raw_select from lock distinct order) %}
          @{{segment.id}} = other.@{{segment.id}}.clone unless except.includes?({{segment}})
        {% end %}

        @adapter = other.@adapter

        @joins = other.@joins.clone unless except.includes?("join")
        @unions = other.@unions.clone unless except.includes?("union")
        @groups = other.@groups.clone unless except.includes?("group")
        @ctes = other.@ctes.clone unless except.includes?("cte")
        @do_nothing = except.includes?("none") ? false : other.@do_nothing
        @select_fields = other.@select_fields unless except.includes?("select")
        @tree = other.@tree.clone unless except.includes?("where")

        @table = other.@table.clone
        @table_aliases = other.@table_aliases.clone

        @relation_used = false
        @expression = ExpressionBuilder.new(@table)
      end

      # Compare current object with given comparing generated SQL query and parameters.
      #
      # Is used for testing.
      def eql?(other : Query)
        sql_args == other.sql_args && as_sql == other.as_sql
      end

      def eql?(other : Statement | LogicOperator)
        false
      end

      # Creates a clone of the query.
      #
      # ```
      # query = Jennifer::Query["contacts"].where { _city == "Kyiv" }
      # query.clone.where { _name.like("John%") }
      # query.clone.where { _name.like("Peter%") }
      # ```
      def clone
        clone = {{@type}}.allocate
        clone.initialize_copy(self)
        clone.expression_builder.query = clone
        clone
      end

      # Creates a clone of the query without specified *parts*.
      #
      # Allowed values for *parts*:
      #
      # * select
      # * raw_select
      # * from
      # * where
      # * having
      # * limit
      # * offset
      # * lock
      # * distinct
      # * order
      # * join
      # * union
      # * group
      # * none
      # * cte
      #
      # Any eager loading isn't copied to a new query.
      #
      # ```
      # Jennifer::Query["contacts"].where { _city == "Paris" }.except(["where"])
      # ```
      def except(parts : Array(String))
        clone = {{@type}}.allocate
        clone.initialize_copy_without(self, parts)
        clone.expression_builder.query = clone
        clone
      end

      # Returns current query expression builder.
      def expression_builder
        @expression
      end

      # Returns array of `Criteria` for `SELECT` query statement.
      def _select_fields : Array(Criteria)
        if @select_fields.nil?
          [@expression.star] of Criteria
        else
          @select_fields.as(Array(Criteria))
        end
      end

      # Builds query with related expression builder.
      #
      # Should be used instead of `.new`.
      #
      # ```
      # Jennifer::Query.build("contacts").where { _name == "Jack London" }
      # ```
      def self.build(*args)
        q = new(*args)
        q.expression_builder.query = q
        q
      end

      # Alias for `.build`.
      #
      # ```
      # Jennifer::Query["contacts"].where { _name == "Jack London" }
      # ```
      def self.[](*args)
        build(*args)
      end

      def as_sql
        as_sql(adapter.sql_generator)
      end

      def as_sql(generator)
        generator.select(self)
      end

      def sql_args : Array(DBAny)
        args = [] of DBAny
        args.concat(select_filterable_arguments) if select_filterable_arguments?
        args.concat(@from.as(Query).sql_args) if @from.is_a?(Query)
        _joins!.each { |join| args.concat(join.sql_args) } if @joins
        args.concat(@tree.not_nil!.sql_args) if @tree
        args.concat(@having.not_nil!.sql_args) if @having
        _ctes!.each { |cte| args.concat(cte.sql_args) } if @ctes
        _unions!.each { |union_tuple| args.concat(union_tuple[:query].sql_args) } if @unions
        args
      end

      # :nodoc:
      def with_relation!
        @relation_used = true
      end

      # :nodoc:
      def with_relation?
        @relation_used
      end

      def empty?
        @tree.nil? && @limit.nil? && @offset.nil? && @joins.nil? && @order.nil?
      end

      # Allows executing a block in the query context.
      #
      # ```
      # Jennifer::Query["contacts"].exec { where { _name == "Jack London" } }
      # ```
      def exec(&)
        with self yield
        self
      end

      # Mutates query applying all modification returned from the block.
      #
      # Yields the expression builder and block is also executed with expression builder context.
      #
      # ```
      # User.where { _email == "example@test.com" }
      # ```
      def where(&)
        other = (with @expression yield @expression)
        set_tree(other)
        self
      end

      # Mutates query by given conditions.
      #
      # All key-value pairs are treated as a sequence of equal conditions
      #
      # ```
      # Jennifer::Query["contacts"].where({:name => "test", :age => 23})
      # # SELECT contacts.* FROM contacts WHERE (contacts.name = 'test' AND contacts.age = 23)
      # ```
      def where(conditions : Hash(Symbol | String, _))
        array = conditions.map { |field, value| @expression.c(field.to_s).equal(value) }
        set_tree(@expression.and(array))
        self
      end

      # Specifies raw SELECT clause value.
      #
      # ```
      # Jennifer::Query["contacts"].select("name as first_name, age as count").results
      # ```
      def select(raw_sql : String)
        @raw_select = raw_sql
        self
      end

      # Specifies criterion to be used in SELECT clause.
      #
      # ```
      # Jennifer::Query["contacts"].exec { select(expression._name.alias("first_name")) }.results
      # ```
      def select(field : Criteria)
        _select_fields! << field
        field.as(RawSql).without_brackets if field.is_a?(RawSql)
        self
      end

      # Specifies column names to be used in SELECT clause.
      def select(*fields : Symbol)
        fields.each { |field| _select_fields! << @expression.c(field.to_s) }
        self
      end

      def select(fields : Array(Criteria))
        fields.each { |field| self.select(field) }
        self
      end

      def select(&)
        fields = with @expression yield @expression
        raise ArgumentError.new("returned value is not an array") unless fields.is_a?(Array)

        fields.each do |field|
          field.as(RawSql).without_brackets if field.is_a?(RawSql)
        end
        _select_fields!.concat(fields)
        self
      end

      # Specifies table *from* which the records will be fetched.
      #
      # Can accept other query.
      #
      # ```
      # # FROM contacts
      # Jennifer::Query[""].from("contacts") # FROM contacts
      # # FROM (SELECT users.* WHERE users.active)
      # Jennifer::Query["contacts"].from(Jennifer::Query["users"].where { _active })
      # ```
      def from(from : String | Query)
        @from = from
        self
      end

      # Returns a chainable query with zero records.
      #
      # ```
      # Jennifer::Query["contacts"].where { _name == "Jack London" }.none
      # ```
      def none
        @do_nothing = true
        self
      end

      # Allows to specify a HAVING clause.
      #
      # Note that you can’t use HAVING without specifying a GROUP clause.
      def having(&)
        other = with @expression yield @expression
        if @having.nil?
          @having = other
        else
          @having = @having.not_nil! & other
        end
        self
      end

      # Adds *query* to `UNION`.
      #
      # To use `UNION ALL` pass `true` as a second argument.
      #
      # ```
      # Jennifer::Query["contacts"].union(Jennifer::Query["users"])
      # Jennifer::Query["contacts"].union(Jennifer::Query["users"], true)
      # ```
      def union(query, all : Bool = false)
        _unions! << {query: query, all: all}
        self
      end

      # Specifies whether the records should be unique or not.
      def distinct
        @distinct = true
        self
      end

      # Groups by given column realizes it as is.
      #
      # ```
      # Jennifer::Query["contacts"].group("first_name || last_name")
      # ```
      def group(column : String)
        _groups! << @expression.sql(column, false)
        self
      end

      # Groups by given *column* realizing it as a current table's field.
      #
      # ```
      # Jennifer::Query["contacts"].group(:name)
      # ```
      def group(column : Symbol)
        _groups! << @expression.c(column.to_s)
        self
      end

      # Groups by given columns realizes them as are
      def group(*columns : String)
        columns.each { |column| _groups! << @expression.sql(column, false) }
        self
      end

      # Groups by given columns realizes them as current table's ones
      def group(*columns : Symbol)
        columns.each { |column| _groups! << @expression.c(column.to_s) }
        self
      end

      def group(column : Criteria)
        column.as(RawSql).without_brackets if column.is_a?(RawSql)
        _groups! << column
        self
      end

      def group(&)
        fields = with @expression yield @expression
        raise ArgumentError.new("returned value is not an array") unless fields.is_a?(Array)

        fields.each { |field| field.as(RawSql).without_brackets if field.is_a?(RawSql) }
        _groups!.concat(fields)
        self
      end

      # Adds CTE (common table expression) to the query.
      #
      # You can define multiple CTE for one query.
      #
      # ```
      # # WITH RECURSIVE test AS (SELECT users.* FROM users )
      # Jennifer::Query["contacts"].with("test", Jennifer::Query["users"])
      #
      # # WITH RECURSIVE test AS (SELECT users.* FROM users )
      # Jennifer::Query["contacts"].with("test", Jennifer::Query["users"], true)
      # ```
      def with(name : String | Symbol, query : Query, recursive : Bool = false)
        _ctes! << CommonTableExpression.new(name.to_s, query, recursive)
        self
      end

      # Merges other query into current one.
      #
      # This method merges the following query components:
      #
      # - `JOIN`s
      # - `GROUP BY`s
      # - `ORDER`s
      # - `CTE`s
      # - `HAVING`s
      # - `WHERE`s
      # - do nothing
      #
      # ```
      # # returns contacts that have main address
      # addresses_condition = Jennifer::Query["addresses"].where { _main }
      # Jennifer::Query["contacts"].join("addresses") { _contact_id == _contacts__id }
      #   .merge(addresses_condition)
      # ```
      #
      # This method provides mechanism to reuse some predefined queries for involved tables.
      # It makes real sense when is used in the scope of `ModelQuery` and models.
      #
      # ```
      # Contacts.all.relation(:addresses).merge(Address.all.main)
      # ```
      def merge(other : self)
        {% for segment in %w(order joins groups ctes) %}
          _{{segment.id}}!.concat(other._{{segment.id}}!) if other._{{segment.id}}?
        {% end %}

        if other._having?
          @having =
            if _having?
              _having! & other._having!
            else
              other._having!
            end
        end

        set_tree(other.tree) if other.tree

        @do_nothing = @do_nothing || other.do_nothing?
        self
      end

      # Specifies a limit for the number of records to retrieve.
      #
      # ```
      # Jennifer::Query["contacts"].limit(10)
      # ```
      def limit(count : Int32)
        @limit = count
        self
      end

      # Specifies the number of rows to skip before returning rows.
      # The offset could be Int32 or Int64.
      #
      # ```
      # Offset in Int32
      # Jennifer::Query["contacts"].offset(10)
      # Or in Int64
      # Jennifer::Query["contacts"].offset(10_i64)
      # ```
      def offset(count : Int32 | Int64)
        @offset = count
        self
      end

      # Specifies locking settings.
      #
      # `true` is default value. Also string declaration can be provide.
      #
      # Also `SKIP LOCKED` construction can be used with manual mode:
      #
      # ```
      # Queue.all.where do
      #   _id == g(Queue.all.limit(1).lock("FOR UPDATE SKIP LOCKED"))
      # end.delete
      # ```
      def lock(type : String | Bool = true)
        @lock = type
        self
      end

      def to_s(io : IO)
        io << as_sql
      end

      # Joins given *other* condition statement to the main condition tree.
      def set_tree(other : LogicOperator | Condition)
        @tree =
          if @tree
            @tree.as(Condition | LogicOperator) & other
          else
            other
          end
        self
      end

      # :ditto:
      def set_tree(other : Query)
        set_tree(other.tree)
      end

      # :ditto:
      def set_tree(other : SQLNode)
        set_tree(other.to_condition)
      end

      # :ditto:
      def set_tree(other : Nil)
        raise ArgumentError.new("Condition tree can't be blank.")
      end

      def filterable? # ameba:disable Metrics/CyclomaticComplexity
        select_filterable_arguments? ||
          (@from.is_a?(Query) && @from.as(Query).filterable?) ||
          (_joins? && _joins!.any?(&.filterable?)) ||
          (!@tree.nil? && @tree.not_nil!.filterable?) ||
          (!@having.nil? && @having.not_nil!.filterable?) ||
          (!@unions.nil? && _unions!.any?(&.[:query].filterable?)) ||
          (!@ctes.nil? && _ctes!.any?(&.filterable?))
      end

      # Returns a JSON string representing collection of retrieved entities.
      #
      # For more details see `Resource#to_json`
      #
      # ```
      # Jennifer::Query["user"].to_json
      # # => [{"id": 1, "name": "John Smith"}]
      # ```
      def to_json(only : Array(String)? = nil, except : Array(String)? = nil, &)
        JSON.build do |json|
          to_json(json, only, except) { |_, entry| yield json, entry }
        end
      end

      def to_json(json : JSON::Builder)
        to_json(json) { }
      end

      def to_json(json : JSON::Builder, only : Array(String)? = nil, except : Array(String)? = nil, &)
        json.array do
          each do |entry|
            entry.to_json(json, only, except) { yield json, entry }
          end
        end
      end

      def to_json(only : Array(String)? = nil, except : Array(String)? = nil)
        JSON.build do |json|
          to_json(json, only, except) { }
        end
      end

      #
      # private methods
      #

      private def select_filterable_arguments?
        @select_fields && _select_fields!.any?(&.filterable?)
      end

      private def select_filterable_arguments
        args = [] of DBAny
        _select_fields!.each do |field|
          args.concat(field.sql_args) if field.filterable?
        end
        args
      end

      private def _groups(name : String)
        @group[name] ||= [] of String
      end
    end
  end

  # Shortcut for the query class name.
  alias Query = QueryBuilder::Query
end
