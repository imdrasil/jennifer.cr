require "./criteria"

module Jennifer
  module QueryBuilder
    class Condition
      include LogicOperator::Operators

      RAW_OPERATORS = [:is, :is_not]

      getter lhs : Criteria, rhs : Criteria::Rightable?, operator : Symbol = :bool

      @negative = false

      def_clone

      def initialize(field : String, table : String, relation = nil)
        @lhs = Criteria.new(field, table, relation)
      end

      def initialize(@lhs)
      end

      def initialize(@lhs, @operator, @rhs)
      end

      protected def initialize_copy(other)
        @rhs = other.@rhs.dup
        @lhs = other.@lhs.clone
        @operator = other.operator
        @negative = other.@negative
      end

      def set_relation(table, name)
        @lhs.set_relation(table, name)
        @rhs.as(Criteria).set_relation(table, name) if @rhs.is_a?(Criteria)
      end

      def alias_tables(aliases)
        @lhs.alias_tables(aliases)
        @rhs.as(Criteria).alias_tables(aliases) if @rhs.is_a?(Criteria)
      end

      def change_table(old_name, new_name)
        @lhs.change_table(old_name, new_name)
        @rhs.as(Criteria).change_table(old_name, new_name) if @rhs.is_a?(Criteria)
      end

      def not
        @negative = !@negative
        self
      end

      def to_s
        as_sql
      end

      def as_sql
        as_sql(Adapter.default_adapter.sql_generator)
      end

      def as_sql(generator)
        _lhs = @lhs.as_sql(generator)
        str =
          case @operator
          when :bool
            _lhs
          when :in
            "#{_lhs} IN(#{generator.escape_string(@rhs.as(Array).size)})"
          when :between
            "#{_lhs} BETWEEN #{generator.escape_string(1)} AND #{generator.escape_string(1)}"
          else
            "#{_lhs} #{generator.operator_to_sql(@operator)} #{parsed_rhs(generator)}"
          end
        str = "NOT (#{str})" if @negative
        str
      end

      def sql_args : Array(DBAny)
        res = @lhs.sql_args
        if filterable? && !(@operator == :is || @operator == :is_not)
          if @operator == :in || @operator == :between
            @rhs.as(Array).each do |e|
              unless e.is_a?(Criteria)
                res << e.as(DBAny)
              else
                res += e.sql_args
              end
            end
          else
            res << @rhs.as(DBAny)
          end
        elsif @rhs.is_a?(Criteria)
          res += @rhs.as(Criteria).sql_args
        end
        res
      end

      def sql_args_count
        count = @lhs.sql_args_count
        if filterable? && !(@operator == :is || @operator == :is_not)
          count = 0
          if @operator == :in || @operator == :between
            @rhs.as(Array).each do |e|
              count += e.is_a?(Criteria) ? e.sql_args_count : 1
            end
          else
            count += 1
          end
        elsif @rhs.is_a?(Criteria)
          count += @rhs.as(Criteria).sql_args_count
        end
        count
      end

      private def filterable?
        !(
          @rhs.is_a?(Criteria) ||
            @operator == :bool
        )
      end

      private def parsed_rhs(generator)
        if @rhs.is_a?(Criteria)
          @rhs.as(Criteria).as_sql(generator)
        elsif @operator == :is || @operator == :is_not
          translate(generator)
        elsif filterable?
          generator.filter_out(@rhs)
        else
          @rhs.to_s
        end
      end

      private def translate(generator)
        case @rhs
        when nil, true, false
          generator.quote(@rhs.as(Nil | Bool))
        when :unknown
          "UNKNOWN"
        when :nil
          generator.quote(nil)
        end
      end
    end
  end
end
