module Jennifer
  module QueryBuilder
    module Ordering
      # Allow to specify an order by splatted named tuple.
      #
      # ```
      # Contact.all.order(name: :asc)
      # ```
      def order(**opts)
        opts.each do |k, v|
          expression = @expression.c(k.to_s).asc
          expression.direction = v
          _order! << expression
        end
        self
      end

      # Allow to specify an order by hash with string keys.
      #
      # ```
      # Contact.all.order({"name" => :asc})
      # ```
      def order(opts : Hash(String, String | Symbol))
        opts.each do |k, v|
          expression = @expression.sql(k.to_s, false).asc
          expression.direction = v
          _order! << expression
        end
        self
      end

      # Allow to specify an order by hash with symbol keys.
      #
      # ```
      # Contact.all.order({:name => :asc})
      # ```
      def order(opts : Hash(Symbol, String | Symbol))
        opts.each do |k, v|
          expression = @expression.c(k.to_s).asc
          expression.direction = v
          _order! << expression
        end
        self
      end

      # Allow to specify an order by *OrderExpression*.
      #
      # ```
      # Contact.all.order(Contact._name.asc)
      # ```
      def order(opt : OrderExpression)
        _order! << opt
        self
      end

      # Allow to specify an order by *OrderExpression* array.
      #
      # ```
      # Contact.all.order([Contact._name.asc])
      # ```
      def order(opts : Array(OrderExpression))
        opts.each { |opt| _order! << opt }
        self
      end

      def order(opts : Hash(String | Symbol, String | Symbol))
        opts.each do |k, v|
          field = k.is_a?(String) ? @expression.sql(k, false) : @expression.c(k.to_s)
          expression = field.asc
          expression.direction = v
          _order! << expression
        end
        self
      end

      # Allow to specify an order passing a block.
      #
      # ```
      # Contact.all.order { _name.asc }
      # Contact.all.order { [_name.asc, _age.desc] }
      # ```
      #
      # Specified block should return `OrderExpression | Array(OrderExpression)`.
      # To convert `Criteria` or `RawSql` to order item call `#asc` or `#desc`.
      def order(&)
        order(with @expression yield @expression)
      end

      # Replace an existing order with the newly specified.
      #
      # ```
      # Contact.all.order(name: :asc).reorder(age: :desc) # ORDER BY contacts.age DESC
      # ```
      def reorder(**opts)
        @order = nil
        order(**opts)
      end

      def reorder(opts : Hash(String, String | Symbol))
        @order = nil
        order(opts)
      end

      def reorder(opts : Hash(Symbol, String | Symbol))
        @order = nil
        order(opts)
      end

      def reorder(opt : OrderExpression)
        @order = nil
        order(opt)
      end

      def reorder(opts : Array(OrderExpression))
        @order = nil
        order(opts)
      end

      def reorder(opts : Hash(String | Symbol, String | Symbol))
        @order = nil
        order(opts)
      end

      def reorder(&)
        reorder(with @expression yield @expression)
      end

      # Show whether order is specified.
      def ordered?
        !!_order?
      end

      private def reverse_order
        if _order?
          _order!.each(&.reverse)
        else
          _order! << @expression.c("id").desc
        end
      end
    end
  end
end
