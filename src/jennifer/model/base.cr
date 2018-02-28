require "./resource"
require "./mapping"
require "./sti_mapping"
require "./validation"
require "./callback"
require "./parameter_converter"

module Jennifer
  module Model
    abstract class Base < Resource
      include Mapping
      include STIMapping
      include Validation
      include Callback

      module ClassMethods
        abstract def relations
        abstract def relation(name)
      end

      extend ClassMethods

      @@table_name : String?
      @@foreign_key_name : String?
      @@actual_table_field_count : Int32?
      @@has_table : Bool?

      def self.has_table?
        @@has_table ||= adapter.table_exists?(table_name).as(Bool)
      end

      # Represent actual amount of model's table column amount (is greped from db).
      def self.actual_table_field_count
        @@actual_table_field_count ||= adapter.table_column_count(table_name)
      end

      def self.table_name(value : String | Symbol)
        @@table_name = value.to_s
      end

      def self.table_name : String
        @@table_name ||=
          begin
            name = ""
            class_name = Inflector.demodulize(to_s)
            name = self.table_prefix if self.responds_to?(:table_prefix)
            Inflector.pluralize(name + class_name.underscore)
          end
      end

      def self.foreign_key_name(value : String | Symbol)
        @@foreign_key_name = value.to_s
      end

      def self.foreign_key_name
        @@foreign_key_name ||= Inflector.singularize(table_name) + "_id"
      end

      def self.parameter_converter
        @@converter ||= ParameterConverter.new
      end

      def self.build_params(hash : Hash(String, String?)) : Hash(String, Jennifer::DBAny)
        {} of String => Jennifer::DBAny
      end

      def self.build(values : Hash | NamedTuple, new_record : Bool)
        o = new(values, new_record)
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
        o = build({} of String => DBAny)
        o.save
        o
      end

      def self.create(**opts)
        o = build(**opts)
        o.save
        o
      end

      def self.create!(values : Hash | NamedTuple)
        o = build(values)
        o.save!
        o
      end

      def self.create!
        o = build({} of Symbol => DBAny)
        o.save!
        o
      end

      def self.create!(**opts)
        o = build(**opts)
        o.save!
        o
      end

      private def init_attributes(values : Hash)
      end

      abstract def set_attribute(name, value)

      def self.models
        {% begin %}
          [
            {% for model in @type.all_subclasses %}
              {{model.id}},
            {% end %}
          ]
        {% end %}
      end

      def update(hash : Hash | NamedTuple)
        update_attributes(hash)
        save
      end

      def update(**opts)
        update(opts)
      end

      def update!(hash : Hash | NamedTuple)
        update_attributes(hash)
        save!
      end

      def update!(**opts)
        update!(opts)
      end

      def update_attributes(hash : Hash | NamedTuple)
        hash.each { |k, v| set_attribute(k, v) }
      end

      def update_attributes(**opts)
        update_attributes(opts)
      end

      # Perform destroy without starting a transaction
      def destroy_without_transaction
        return false if new_record? || !__before_destroy_callback
        @destroyed = true if delete
        __after_destroy_callback if @destroyed
        @destroyed
      end

      # Deletes object from DB without calling callbacks.
      def delete
        return if new_record? || errors.any?
        this = self
        self.class.all.where { this.class.primary == this.primary }.delete
      end

      # Lock current object in DB.
      def lock!(type : String | Bool = true)
        this = self
        self.class.all.where { this.class.primary == this.primary }.lock(type).to_a
      end

      # Starts transaction and locks current object.
      def with_lock(type : String | Bool = true)
        self.class.transaction do |t|
          self.lock!(type)
          yield(t)
        end
      end

      # Performs table lock for current model's table.
      def self.with_table_lock(type : String | Symbol, &block)
        adapter.with_table_lock(table_name, type.to_s) do |t|
          yield t
        end
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

      def self.import(collection : Array(self))
        adapter.bulk_insert(collection)
      end

      macro inherited
        ::Jennifer::Model::Validation.inherited_hook
        ::Jennifer::Model::Callback.inherited_hook
        ::Jennifer::Model::RelationDefinition.inherited_hook

        @@relations = {} of String => ::Jennifer::Relation::IRelation

        after_save :__refresh_changes
        before_save :__check_if_changed

        def self.relations
          @@relations
        end

        def self.superclass
          {{@type.superclass}}
        end

        macro finished
          ::Jennifer::Model::Validation.finished_hook
          ::Jennifer::Model::Callback.finished_hook

          def self.relation(name : String)
            @@relations[name]
          rescue e : KeyError
            raise Jennifer::UnknownRelation.new(self, e)
          end
        end
      end
    end
  end
end
