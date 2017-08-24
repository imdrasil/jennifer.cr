module Jennifer
  module Relation
    class ManyToMany(T, Q) < Base(T, Q)
      getter join_table : String?, join_foreign : String?

      def initialize(@name, foreign : String | Symbol?, primary : String | Symbol?, query, @join_table = nil, _join_foreign = nil)
        @join_foreign = _join_foreign.to_s if _join_foreign
        @foreign = foreign.to_s if foreign
        @primary = primary.to_s if primary
        @join_query = query.tree
        @join_query.not_nil!.set_relation(T.table_name, @name) if @join_query
        @join_table = ::Jennifer::Adapter.adapter_class.join_table_name(Q.table_name, T.table_name) unless @join_table
      end

      def join_table!
        @join_table.not_nil!
      end

      def insert(obj : Q, rel : Hash)
        new_obj = T.create!(rel)
        add_join_table_record(obj, new_obj)
        new_obj
      end

      def insert(obj : Q, rel : T)
        rel.save! if rel.new_record?
        add_join_table_record(obj, rel)
        rel
      end

      def remove(obj : Q, rel : T)
        this = self
        _obj = obj.attribute(primary_field)
        _rel = rel.primary
        QueryBuilder::Query.new(join_table!).where do
          (c(this.foreign_field) == _obj) & (c(this.join_table_foreign_key) == _rel)
        end.delete
        rel
      end

      def query(primary_value)
        jtk = join_table_foreign_key
        _primary_value = primary_value
        _ff = foreign_field
        q = T.all.join(@join_table.not_nil!) { (c(jtk) == T.primary) & (c(_ff) == _primary_value) }
        if @join_query
          _tree = @join_query.not_nil!
          q.where { _tree }
        else
          q
        end
      end

      def join_condition(query, type)
        _foreign = foreign_field
        _primary = primary_field
        jt = @join_table.not_nil!
        jtk = @join_foreign || T.to_s.foreign_key
        q = query.join(jt, type: type) { Q.c(_primary) == c(_foreign) }.join(T, type: type) do
          T.primary == c(jtk, jt)
        end
        if @join_query
          _tree = @join_query.not_nil!
          q.where { _tree }
        else
          q
        end
      end

      def join_table_foreign_key
        @join_foreign || T.to_s.foreign_key
      end

      private def add_join_table_record(obj, rel)
        Adapter.adapter.insert(
          join_table!,
          {
            foreign_field          => obj.attribute(primary_field),
            join_table_foreign_key => rel.primary,
          }
        )
      end
    end
  end
end
