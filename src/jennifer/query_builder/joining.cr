module Jennifer
  module QueryBuilder
    module Joining
      # Adds `JOIN` of the *source*'s class table to the request.
      #
      # You can pass table alias which will be automatically used by given expression builder.
      #
      # Method block provides two arguments:
      #
      # * expression builder for the table that is mentioned in the `FROM` clause;
      # * expression builder for the table that is joined.
      #
      # At the same time block is executed in context of **joined** table.
      #
      # ```
      # Contact.all.join(Address) { |t| _contact_id == t._id }
      # # => JOIN addresses ON addresses.contact_id = contacts.id
      #
      # Contact.all.join(Address, "some_table") { |t| _contact_id == t._id }
      # # => JOIN addresses some_table ON some_table.contact_id = contacts.id
      # ```
      def join(source : Class, table_alias : String? = nil, type = :inner, relation : String? = nil, &)
        eb = joined_context(source, relation, table_alias)
        with_relation! if relation
        other = with eb yield @expression, eb
        _joins! << Join.new(source.table_name, other, type, table_alias, relation)
        self
      end

      # Adds `JOIN` of *source* table to the request.
      #
      # ```
      # Contact.all.join("addresses") { |t| _contact_id == t._id }
      # # => JOIN addresses ON addresses.contact_id = contacts.id
      # ```
      def join(source : String, table_alias : String? = nil, type = :inner, relation : String? = nil, &)
        eb = joined_context(source, relation, table_alias)
        with_relation! if relation
        other = with eb yield @expression, eb
        _joins! << Join.new(source, other, type, table_alias, relation)
        self
      end

      # Adds `JOIN` of *source* query to the request.
      #
      # ```
      # Contact.all.join(Address.all, "some_table") { |t| _contact_id == t._id }
      # # => JOIN (SELECT addresses.* FROM addresses) some_table ON some_table.contact_id = contacts.id
      # ```
      def join(source : Query, table_alias : String, type = :inner, &)
        eb = joined_context(source, table_alias)
        other = with eb yield @expression, eb
        _joins! << Join.new(source, other, type, table_alias)
        self
      end

      # Adds `JOIN LATERAL` of *source* query to the request.
      #
      # ```
      # Contact.all.lateral_join(Address.all, "some_table") { |t| _contact_id == t._id }
      # # => JOIN LATERAL (SELECT addresses.* FROM addresses) some_table ON some_table.contact_id = contacts.id
      # ```
      def lateral_join(source : Query, table_alias : String, type = :inner, &)
        eb = joined_context(source, table_alias)
        other = with eb yield @expression, eb
        _joins! << LateralJoin.new(source, other, type, table_alias)
        self
      end

      # Adds `LEFT JOIN` of the *source*'s class table to the request.
      #
      # Alias for `join(source, table_alias, :left)`.
      def left_join(source : Class, table_alias : String? = nil, &)
        join(source, table_alias, :left) { |own_table, joined_table| with joined_table yield own_table, joined_table }
      end

      # Adds `LEFT JOIN` of *source* table to the request.
      #
      # Alias for `join(source, table_alias, :left)`.
      def left_join(source : String, table_alias : String? = nil, &)
        join(source, table_alias, :left) { |own_table, joined_table| with joined_table yield own_table, joined_table }
      end

      # Adds `RIGHT JOIN` of the *source*'s class table to the request.
      #
      # Alias for `join(source, table_alias, :right)`.
      def right_join(source : Class, table_alias : String? = nil, &)
        join(source, table_alias, :right) { |own_table, joined_table| with joined_table yield own_table, joined_table }
      end

      # # Adds `RIGHT JOIN` of *source* table to the request.
      #
      # Alias for `join(source, table_alias, :right)`.
      def right_join(source : String, table_alias : String? = nil, &)
        join(source, table_alias, :right) { |own_table, joined_table| with joined_table yield own_table, joined_table }
      end

      private def joined_context(source : Class, relation : String?, table_alias : String)
        ExpressionBuilder.new(table_alias, relation, self)
      end

      private def joined_context(source : String, table_alias : String)
        ExpressionBuilder.new(table_alias, relation, self)
      end

      private def joined_context(source : Class, relation : String?, table_alias : Nil)
        ExpressionBuilder.new(source.table_name, relation, self)
      end

      private def joined_context(source : String, relation : String?, table_alias : Nil)
        ExpressionBuilder.new(source, relation, self)
      end

      private def joined_context(source : Query, table_alias : String)
        ExpressionBuilder.new(table_alias, nil, self)
      end
    end
  end
end
