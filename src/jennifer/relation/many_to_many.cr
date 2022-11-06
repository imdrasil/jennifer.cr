module Jennifer
  module Relation
    class ManyToMany(T, Q) < Base(T, Q)
      getter join_table : String?, association_foreign : String?

      def initialize(@name, foreign : String | Symbol?, primary : String | Symbol?, query, @join_table = nil, _join_foreign = nil)
        @association_foreign = _join_foreign.to_s if _join_foreign
        @foreign = foreign.to_s if foreign
        @primary = primary.to_s if primary
        @join_query = query.tree
        @join_query.not_nil!.set_relation(T.table_name, @name) if @join_query
      end

      def join_table!
        @join_table ? @join_table.not_nil! : adapter.class.join_table_name(Q.table_name, T.table_name)
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
        primary_value = obj.attribute_before_typecast(primary_field)
        association_primary_value = rel.attribute_before_typecast(T.primary_field_name)
        QueryBuilder::Query.new(join_table!).where do
          (c(this.foreign_field) == primary_value) & (c(this.association_foreign_key) == association_primary_value)
        end.delete
        rel
      end

      def query(primary_value_or_array)
        afk = association_foreign_key
        _primary_value = primary_value_or_array
        mfk = foreign_field
        q = T.all.join(join_table!) do
          (c(afk) == T.primary) &
            (_primary_value.is_a?(Array) ? c(mfk).in(_primary_value) : c(mfk) == _primary_value)
        end
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
        jt = join_table!
        q = query.join(jt, type: type) { Q.c(_primary) == c(_foreign) }.join(T, type: type) do
          T.primary == c(association_foreign_key, jt)
        end
        if @join_query
          _tree = @join_query.not_nil!
          q.where { _tree }
        else
          q
        end
      end

      def association_foreign_key
        @association_foreign || Wordsmith::Inflector.foreign_key(T.to_s)
      end

      def preload_relation(collection, out_collection : Array(Model::Resource), pk_repo)
        return if collection.empty?
        _primary = primary_field

        unless pk_repo.has_key?(_primary)
          array = pk_repo[_primary] = Array(DBAny).new(collection.size)
          collection.each { |e| array << e.attribute_before_typecast(_primary) }
        end

        join_fk = "__join_fk__"
        query = query(pk_repo[_primary])
        fields = query._select_fields
        fields << QueryBuilder::Criteria.new(foreign_field, join_table!).alias(join_fk)
        new_collection = query.select(fields).db_results

        name = self.name
        if new_collection.empty?
          collection.each(&.relation_retrieved(name))
        else
          primary_fields = pk_repo[_primary]
          collection.each_with_index do |mod, i|
            pv = primary_fields[i]
            new_collection.each { |hash| out_collection << mod.append_relation(name, hash) if hash[join_fk] == pv }
          end
        end
      end

      private def add_join_table_record(obj, rel)
        adapter.insert(
          join_table!,
          {
            foreign_field           => obj.attribute_before_typecast(primary_field),
            association_foreign_key => rel.primary,
          }
        )
      end
    end
  end
end
