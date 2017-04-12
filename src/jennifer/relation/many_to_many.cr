module Jennifer
  module Relation
    class ManyToMany(T, Q) < Base(T, Q)
      def initialize(*opts)
        super
        @join_table = ::Jennifer::Adapter.adapter_class.join_table_name(Q.table_name, T.table_name) unless @join_table
      end

      def insert(obj : Q, rel : Hash)
        new_obj = T.create!(rel)
        args = {
          foreign_field          => obj.attribute(primary_field),
          join_table_foreign_key => new_obj.primary,
        }
        Adapter.adapter.insert_join_table(join_table.not_nil!, args).inspect
        new_obj
      end

      def insert(obj : Q, rel : T)
        if rel.new_record?
          rel.save!
        end
        args = {
          foreign_field          => obj.attribute(primary_field),
          join_table_foreign_key => rel.primary,
        }
        Adapter.adapter.insert_join_table(@join_table.not_nil!, args)
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
    end
  end
end
