require "./mapping"
require "./sti_mapping"
require "./validation"
require "./callback"
require "./relation_definition"
require "./scoping"

module Jennifer
  module Model
    abstract class Base
      extend Ifrit
      include Mapping
      include STIMapping
      include Validation
      include Callback
      include RelationDefinition
      include Scoping

      alias Supportable = DBAny | Base

      MODELS = [] of String

      @@table_name : String?
      @@singular_table_name : String?
      @@actual_table_field_count : Int32?
      @@has_table : Bool?

      def self.has_table?
        @@has_table ||= Jennifer::Adapter.adapter.table_exists?(table_name).as(Bool)
      end

      # Represent actual amount of model's table column amount (is greped from db).
      def self.actual_table_field_count
        @@actual_table_field_count ||= ::Jennifer::Adapter.adapter.table_column_count(table_name)
      end

      def self.table_name(value : String | Symbol)
        @@table_name = value.to_s
      end

      def self.singular_table_name(value : String | Symbol)
        @@singular_table_name = value.to_s
      end

      def self.c(name)
        ::Jennifer::QueryBuilder::Criteria.new(name, table_name)
      end

      def self.c(name, relation)
        ::Jennifer::QueryBuilder::Criteria.new(name, table_name, relation)
      end

      def self.build(pull : DB::ResultSet)
        o = new(pull)
        o.__after_initialize_callback
        o
      end

      def self.build(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
        o = new(values)
        o.__after_initialize_callback
        o
      end

      def self.build(values : Hash(String, ::Jennifer::DBAny))
        o = new(values)
        o.__after_initialize_callback
        o
      end

      def self.build(values : Hash | NamedTuple, new_record : Bool)
        o = new(values, new_record)
        o.__after_initialize_callback
        o
      end

      def self.build(**values)
        o = new(values)
        o.__after_initialize_callback
        o
      end

      # TODO: not always constructor without arguments could be generated
      # this should be moved to mapping.cr
      def self.build
        o = new
        o.__after_initialize_callback
        o
      end

      def new_record?
        @new_record
      end

      def destroyed?
        @destroyed
      end

      def self.create(values : Hash | NamedTuple)
        o = build(values)
        o.save
        o
      end

      def self.create
        a = {} of String => DBAny
        o = build(a)
        o.save
        o
      end

      def self.create!(values : Hash | NamedTuple)
        o = build(values)
        o.save!
        o
      end

      def self.create!
        o = build({} of Symbol => Supportable)
        o.save!
        o
      end

      def append_relation(name, hash)
        raise Jennifer::UnknownRelation.new(self.class, name)
      end

      abstract def primary
      abstract def attribute(name)
      abstract def set_attribute(name, value)

      macro def self.models
        {% begin %}
          [
            {% for model in @type.all_subclasses %}
              {{model.id}},
            {% end %}
          ]
        {% end %}
      end

      macro inherited
        ::Jennifer::Model::Validation.inherited_hook
        ::Jennifer::Model::Callback.inherited_hook
        ::Jennifer::Model::RelationDefinition.inherited_hook

        @@relations = {} of String => ::Jennifer::Relation::IRelation

        after_save :__refresh_changes
        before_save :__check_if_changed

        def self.table_name : String
          @@table_name ||= {{@type}}.to_s.underscore.pluralize
        end

        def self.singular_table_name
          @@singular_table_name ||= {{@type}}.to_s.underscore
        end

        def self.relations
          @@relations
        end

        def self.superclass
          {{@type.superclass}}
        end

        macro finished
          ::Jennifer::Model::Validation.finished_hook
          ::Jennifer::Model::Callback.finished_hook
          ::Jennifer::Model::RelationDefinition.finished_hook

          def self.relation(name : String)
            @@relations[name]
          rescue e : KeyError
            raise Jennifer::UnknownRelation.new(self, e)
          end
        end
      end

      def update_attributes(hash : Hash)
        hash.each { |k, v| set_attribute(k, v) }
      end

      # Deletes object from db and calls callbacks
      def destroy
        unless ::Jennifer::Adapter.adapter.under_transaction?
          {{@type}}.transaction do
            destroy_without_transaction
          end
        else
          destroy_without_transaction
        end
      end

      def destroy_without_transaction
        return false if new_record? || !__before_destroy_callback
        @destroyed = true if delete
        __after_destroy_callback if @destroyed
        @destroyed
      end

      # Deletes object from DB without calling callbacks
      def delete
        return if new_record? || errors.any?
        this = self
        self.class.all.where { this.class.primary == this.primary }.delete
      end

      # Lock current object in DB
      def lock!(type : String | Bool = true)
        this = self
        self.class.all.where { this.class.primary == this.primary }.lock(type).to_a
      end

      # Starts transaction and locks current object
      def with_lock(type : String | Bool = true)
        self.class.transaction do |t|
          self.lock!(type)
          yield(t)
        end
      end

      # Starts transaction
      def self.transaction
        Adapter.adapter.transaction do |t|
          yield(t)
        end
      end

      def self.where(&block)
        ac = all
        tree = with ac.expression_builder yield
        ac.set_tree(tree)
        ac
      end

      def self.find(id)
        _id = id
        this = self
        all.where { this.primary == _id }.first
      end

      def self.find!(id)
        _id = id
        this = self
        all.where { this.primary == _id }.first!
      end

      def self.all
        QueryBuilder::ModelQuery(self).build(table_name)
      end

      def self.destroy(*ids)
        destroy(ids.to_a)
      end

      def self.destroy(ids : Array)
        _ids = ids
        all.where do
          if _ids.size == 1
            c(primary_field_name) == _ids[0]
          else
            c(primary_field_name).in(_ids)
          end
        end.destroy
      end

      def self.delete(*ids)
        delete(ids.to_a)
      end

      def self.delete(ids : Array)
        _ids = ids
        all.where do
          if _ids.size == 1
            c(primary_field_name) == _ids[0]
          else
            c(primary_field_name).in(_ids)
          end
        end.delete
      end

      def self.search_by_sql(query : String, args = [] of Supportable)
        result = [] of self
        ::Jennifer::Adapter.adapter.query(query, args) do |rs|
          rs.each do
            result << build(rs)
          end
        end
        result
      end
    end
  end
end
