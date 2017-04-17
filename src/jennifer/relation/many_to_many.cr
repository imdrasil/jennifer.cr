module Jennifer
  module Relation
    class ManyToMany(T, Q) < Base(T, Q)
      def initialize(*opts)
        super
        @join_table = ::Jennifer::Adapter.adapter_class.join_table_name(Q.table_name, T.table_name) unless @join_table
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
        QueryBuilder::PlainQuery.new(join_table!).where do
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

      private def add_join_table_record(obj, rel)
        keys = [foreign_field, join_table_foreign_key]
        values = [obj.attribute(primary_field), rel.primary]
        query = String.build do |s|
          s << "INSERT INTO " << join_table! << "("
          keys.join(", ", s)
          s << ") values (" << Adapter.adapter_class.escape_string(2) << ")"
        end

        Adapter.adapter.exec(Adapter.adapter.parse_query(query, keys), values)
      end
    end
  end
end
