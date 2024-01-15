module Jennifer
  module Relation
    class BelongsTo(T, Q) < Base(T, Q)
      def initialize(*opts)
        super
      end

      def condition_clause
        _foreign = foreign_field
        _primary = primary_field
        tree = T.c(_primary, @name) == Q.c(_foreign)
        @join_query ? tree & @join_query.not_nil!.clone : tree
      end

      def condition_clause(ids : Array(DBAny))
        _tree = T.c(primary_field, @name).in(ids)
        @join_query ? _tree & @join_query.not_nil!.clone : _tree
      end

      def condition_clause(id : DBAny)
        _tree = T.c(primary_field, @name) == id
        @join_query ? _tree & @join_query.not_nil!.clone : _tree
      end

      def join_condition(query, type)
        this = self
        query.join(model_class, type: type, relation: @name) do
          this.condition_clause.not_nil!
        end
      end

      def join_condition(query, type, &)
        this = self
        query.join(model_class, type: type, relation: @name) do |table|
          this.condition_clause.not_nil! & (yield table)
        end
      end

      def query(primary_value_or_array)
        condition = condition_clause(primary_value_or_array)
        T.where { condition }
      end

      def insert(obj : Q, rel : Hash(String, T::AttrType))
        main_obj = T.create!(rel)
        obj.update_column(foreign_field, main_obj.attribute(primary_field))
        main_obj
      end

      def insert(obj : Q, rel : T)
        raise BaseException.new("Object already belongs to another object") unless obj.attribute(foreign_field).nil?

        obj.set_attribute(foreign_field, rel.attribute(primary_field))
        rel.save! if rel.new_record?
        rel
      end

      def remove(obj : Q, rel : T)
        obj.update_column(foreign_field, nil) if obj.attribute(foreign_field) == rel.attribute(primary_field)
        rel
      end

      def remove(obj : Q)
        obj.update_column(foreign_field, nil)
      end

      def foreign_field
        @foreign ||= T.foreign_key_name
      end

      def primary_field
        @primary ||= T.primary_field_name
      end

      def preload_relation(collection, out_collection : Array(Model::Resource), pk_repo)
        return if collection.empty?
        _primary = primary_field
        _foreign = foreign_field

        unless pk_repo.has_key?(_foreign)
          array = pk_repo[_foreign] = Array(DBAny).new(collection.size)
          collection.each { |e| array << e.attribute_before_typecast(_foreign) }
        end

        new_collection = query(pk_repo[_foreign]).db_results

        name = self.name
        if new_collection.empty?
          collection.each(&.relation_retrieved(name))
        else
          foreign_fields = pk_repo[_foreign]
          collection.each_with_index do |mod, i|
            fk = foreign_fields[i]
            new_collection.each { |hash| out_collection << mod.append_relation(name, hash) if hash[_primary] == fk }
          end
        end
      end
    end
  end
end
