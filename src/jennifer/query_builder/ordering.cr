module Jennifer
  module QueryBuilder
    module Ordering
      def order(**opts)
        opts.each do |k, v|
          key = @expression.c(k.to_s)
          @order[key] = v.to_s
        end
        self
      end

      def order(opts : Hash(String, String | Symbol))
        opts.each do |k, v|
          @order[@expression.sql(k, false)] = v.to_s
        end
        self
      end

      def order(opts : Hash(Symbol, String | Symbol))
        opts.each do |k, v|
          key = @expression.c(k.to_s)
          @order[key] = v.to_s
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

      def order(opts : Hash(String | Symbol, String | Symbol))
        opts.each do |k, v|
          key = k.is_a?(String) ? @expression.sql(k, false) : @expression.c(k.to_s)
          @order[key] = v.to_s
        end
        self
      end

      def order(&block)
        order(with @expression yield)
      end

      def reorder(**opts)
        reorder(opts.to_h)
      end

      def reorder(opts : Hash(String, String | Symbol))
        @order.clear
        order(opts)
      end

      def reorder(opts : Hash(Symbol, String | Symbol))
        @order.clear
        order(opts)
      end

      def reorder(opts : Hash(Criteria, String | Symbol))
        @order.clear
        order(opts)
      end

      def reorder(opts : Hash(String | Symbol, String | Symbol))
        @order.clear
        order(opts)
      end

      def reorder(&block)
        reorder(with @expression yield)
      end

      def ordered?
        !@order.empty?
      end

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
    end
  end
end
