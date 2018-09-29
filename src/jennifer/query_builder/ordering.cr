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
          @order << expression
        end
        self
      end

      # Allow to specify an order by hash with string keys.
      #
      # ```
      # Contact.all.order({ "name" => :asc })
      # ```
      def order(opts : Hash(String, String | Symbol))
        opts.each do |k, v|
          expression = @expression.sql(k.to_s, false).asc
          expression.direction = v
          @order << expression
        end
        self
      end

      # Allow to specify an order by hash with symbol keys.
      #
      # ```
      # Contact.all.order({ :name => :asc })
      # ```
      def order(opts : Hash(Symbol, String | Symbol))
        opts.each do |k, v|
          expression = @expression.c(k.to_s).asc
          expression.direction = v
          @order << expression
        end
        self
      end

      # Allow to specify an order by *OrderItem*.
      #
      # ```
      # Contact.all.order(Contact._name.asc)
      # ```
      def order(opt : OrderItem)
        @order << opt
        self
      end

      # Allow to specify an order by *OrderItem* array.
      #
      # ```
      # Contact.all.order([Contact._name.asc])
      # ```
      def order(opts : Array(OrderItem))
        opts.each { |opt| @order << opt }
        self
      end

      def order(opts : Hash(String | Symbol, String | Symbol))
        opts.each do |k, v|
          key = k.is_a?(String) ? @expression.sql(k, false) : @expression.c(k.to_s)
          @order[key] = v.to_s
        end
        self
      end

      # Allow to specify an order passing a block.
      #
      # ```
      # Contact.all.order { _name.asc }
      # ```
      def order(&block)
        order(with @expression yield)
      end

      # Replace an existing order with the newly specified.
      #
      # ```
      # Contact.all.order(name: :asc).reorder(name: :desc)
      # ```
      def reorder(**opts)
        @order.clear
        order(**opts)
      end

      def reorder(opts : Hash(String, String | Symbol))
        @order.clear
        order(opts)
      end

      def reorder(opts : Hash(Symbol, String | Symbol))
        @order.clear
        order(opts)
      end

      def reorder(opt : OrderItem)
        @order.clear
        order(opt)
      end

      def reorder(opts : Array(OrderItem))
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

      # Show whether order is specified.
      def ordered?
        !@order.empty?
      end

      private def reverse_order
        if @order.empty?
          @order << @expression.c("id").desc
        else
          @order.each(&.reverse)
        end
      end
    end
  end
end
