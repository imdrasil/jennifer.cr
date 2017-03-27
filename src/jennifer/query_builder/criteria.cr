module Jennifer
  module QueryBuilder
    class Criteria
      alias Rightable = Criteria | DBAny | Array(DBAny)

      getter rhs : Rightable
      getter operator, field, table

      @rhs = ""
      @operator = :bool
      @negative = false

      def initialize(@field : String, @table : String)
      end

      {% for op in [:<, :>, :<=, :>=] %}
        def {{op.id}}(value : Rightable)
          @rhs = value
          @operator = Operator.new({{op}})
          self
        end
      {% end %}

      def =~(value : String)
        regexp(value)
      end

      def regexp(value : String)
        @rhs = value
        @operator = Operator.new(:regexp)
        self
      end

      def not_regexp(value : String)
        @rhs = value
        @operator = Operator.new(:not_regexp)
        self
      end

      def like(value : String)
        @rhs = value
        @operator = Operator.new(:like)
        self
      end

      def not_like(value : String)
        @rhs = value
        @operator = Operator.new(:not_like)
        self
      end

      # postgres only
      def similar(value : String)
        @rhs = value
        @operator = Operator.new(:similar)
        self
      end

      def ==(value : Rightable)
        if !value.nil?
          @rhs = value
          @operator = Operator.new(:==)
        else
          is(value)
        end
        self
      end

      def eq(value : Rightable)
        if !value.nil?
          @rhs = value
          @operator = Operator.new(:==)
        else
          is(value)
        end
        self
      end

      def !=(value : Rightable)
        if !value.nil?
          @rhs = value
          @operator = Operator.new(:!=)
        else
          not(value)
        end
        self
      end

      def is(value : Symbol | Bool | Nil)
        @rhs = translate(value)
        @operator = Operator.new(:is)
        self
      end

      def not(value : Symbol | Bool | Nil)
        @rhs = translate(value)
        @operator = Operator.new(:is_not)
        self
      end

      def not
        @negative = !@negative
        self
      end

      def in(arr : Array)
        raise ArgumentError.new("IN array can't be empty") if arr.empty?
        @rhs = arr.map { |e| e.as(DBAny) }
        @operator = :in
        self
      end

      def &(other : Criteria | LogicOperator)
        op = And.new
        op.add(self)
        op.add(other)
        op
      end

      def |(other : Criteria | LogicOperator)
        op = Or.new
        op.add(self)
        op.add(other)
        op
      end

      def to_s
        to_sql
      end

      def filter_out(arg)
        if arg.is_a?(Criteria)
          arg.to_sql
        else
          ::Jennifer::Adapter.escape_string(1)
        end
      end

      def to_sql
        _field = "#{@table}.#{@field.to_s}"
        str =
          case @operator
          when :bool
            _field
          when :in
            "#{_field} IN(#{::Jennifer::Adapter.escape_string(@rhs.as(Array).size)})"
          else
            "#{_field} #{@operator.to_s} #{@operator.as(Operator).filterable_rhs? ? filter_out(@rhs) : @rhs}"
          end
        str = "NOT (#{str})" if @negative
        str
      end

      def sql_args : Array(DB::Any)
        res = [] of DB::Any
        if @operator != :bool
          if @operator == :in
            @rhs.as(Array).each do |e|
              res << e.as(DB::Any) unless e.is_a?(Criteria)
            end
          elsif !@rhs.is_a?(Criteria)
            res << @rhs.as(DB::Any)
          end
        end
        res
      end

      private def translate(value : Symbol | Bool | Nil)
        case value
        when :nil, nil
          "NULL"
        when :unknown
          "UNKNOWN"
        when true
          "TRUE"
        when false
          "FALSE"
        end
      end
    end
  end
end
