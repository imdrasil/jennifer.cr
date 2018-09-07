require "./logic_operator"

module Jennifer
  module QueryBuilder
    class Condition
      include LogicOperator::Operators

      getter lhs : SQLNode, rhs : Criteria::Rightable?, operator : Symbol = :bool
      @negative = false

      def initialize(field : String, table : String, relation = nil)
        @lhs = Criteria.new(field, table, relation)
      end

      def initialize(@lhs)
      end

      def initialize(@lhs, @operator, @rhs)
      end

      def_clone

      protected def initialize_copy(other)
        @rhs = other.@rhs.dup
        @lhs = other.@lhs.clone
        @operator = other.operator
        @negative = other.@negative
      end

      def set_relation(table, name)
        @lhs.set_relation(table, name)
        @rhs.as(SQLNode).set_relation(table, name) if @rhs.is_a?(SQLNode)
      end

      def alias_tables(aliases)
        @lhs.alias_tables(aliases)
        @rhs.as(SQLNode).alias_tables(aliases) if @rhs.is_a?(SQLNode)
      end

      def change_table(old_name, new_name)
        @lhs.change_table(old_name, new_name)
        @rhs.as(SQLNode).change_table(old_name, new_name) if @rhs.is_a?(SQLNode)
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
            "#{_lhs} IN(#{generator.filter_out(@rhs.as(Array), false)})"
          when :between
            rhs = @rhs.as(Array)
            "#{_lhs} BETWEEN #{generator.filter_out(rhs[0])} AND #{generator.filter_out(rhs[1])}"
          else
            "#{_lhs} #{generator.operator_to_sql(@operator)} #{parsed_rhs(generator)}"
          end
        str = "NOT (#{str})" if @negative
        str
      end

      def sql_args : Array(DBAny)
        res = @lhs.sql_args
        return res if @operator == :bool
        if @rhs.is_a?(SQLNode)
          res.concat(@rhs.as(SQLNode).sql_args)
        elsif @rhs.is_a?(Array) && (@operator == :in || @operator == :between)
          @rhs.as(Array).each do |e|
            unless e.is_a?(SQLNode)
              res << e.as(DBAny)
            else
              res.concat(e.sql_args)
            end
          end
        elsif @operator != :is && @operator != :is_not
          res << @rhs.as(DBAny)
        end
        res
      end

      def filterable?
        if @lhs.filterable?
          true
        elsif @operator == :bool
          false
        elsif @rhs.is_a?(SQLNode)
          @rhs.as(SQLNode).filterable?
        elsif @operator == :is || @operator == :is_not
          false
        elsif @rhs.is_a?(Array)
          @rhs.as(Array).any? { |e| !e.is_a?(SQLNode) || e.filterable? }
        else
          true
        end
      end

      private def parsed_rhs(generator)
        if @rhs.is_a?(SQLNode)
          @rhs.as(SQLNode).as_sql(generator)
        elsif @operator == :is || @operator == :is_not
          translate(generator)
        else
          generator.filter_out(@rhs)
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
