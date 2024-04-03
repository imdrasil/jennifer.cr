require "../relation/base"
require "../relation/*"
require "../model/errors"

require "./resource"
require "./presentable"
require "./mapping"
require "./sti_mapping"
require "./validation"
require "./callback"
require "./coercer"
require "./big_decimal_converter"
require "./enum_converter"
require "./json_converter"
require "./json_serializable_converter"
require "./time_zone_converter"
require "./timestamp"
require "./optimistic_locking"

module Jennifer
  module Model
    abstract class Base < Resource
      # `Base` class abstract methods.
      module AbstractClassMethods
        # Returns whether primary field is autoincrementable.
        abstract def primary_auto_incrementable?

        # Instantiate new object base on given *values*.
        #
        # `after_initialize` callbacks are called after an object is initialized.
        #
        # ```
        # Contact.new({ "name" => "Jennifer" })
        # Contact.new({ :name => "Jennifer" })
        # Contact.new({ name: "Jennifer" })
        # Contact.new(:name: "Jennifer"})
        # # only in a case when all Contact's fields are nillable or with default values
        # Contact.new
        # ```
        abstract def new(values : Hash | NamedTuple)

        # Returns number of model's fields.
        abstract def field_count : Int32

        # Returns array of field names.
        abstract def field_names : Array(String)

        # Returns model's column metadata.
        #
        # The metadata is a result of processing attributes passed to `.mapping` macro.
        abstract def columns_tuple

        abstract def coercer

        # Return `Jennifer::QueryBuilder::Criteria` for primary column or raises a `Jennifer::AbstractMethod`
        abstract def primary

        # Return primary field name or raises a `Jennifer::AbstractMethod`
        abstract def primary_field_name
      end

      extend AbstractClassMethods
      include Presentable
      include Mapping
      include Timestamp
      include OptimisticLocking
      include STIMapping
      include Validation
      include Callback

      @@foreign_key_name : String?

      @[JSON::Field(ignore: true)]
      @new_record : Bool = true
      @[JSON::Field(ignore: true)]
      @destroyed : Bool = false

      # Returns whether model has a table.
      #
      # NOTE: shouldn't be used outside of tests.
      def self.has_table?
        @@has_table = read_adapter.table_exists?(table_name).as(Bool) if @@has_table.nil?
        @@has_table
      end

      # Returns actual model table column amount (is grepped from db).
      #
      # If somewhy you define model with custom table name after the place where adapter is used the first time -
      # manually invoke this method anywhere after table name definition.
      def self.actual_table_field_count
        @@actual_table_field_count ||= read_adapter.table_column_count(table_name).to_i
      end

      # :nodoc:
      def self.actual_table_field_count=(value)
        @@actual_table_field_count = value
      end

      # Sets custom model foreign key name.
      #
      # ```
      # class User < Jennifer::Model::Base
      #   foreign_key_name :client_id
      # end
      # ```
      def self.foreign_key_name(value : String | Symbol)
        @@foreign_key_name = value.to_s
        @@foreign_key_name = nil
      end

      # Returns model foreign key name.
      def self.foreign_key_name
        @@foreign_key_name ||= Wordsmith::Inflector.singularize(table_name) + "_id"
      end

      # Initializes new object based on given arguments.
      #
      # `after_initialize` callbacks are invoked. If model mapping allows creating an object
      # without passing any argument - relevant `#build` method will be generated for such model.
      def self.build(values : Hash | NamedTuple, new_record : Bool)
        new(values, new_record)
      end

      # Returns whether record isn't persisted.
      def new_record?
        @new_record
      end

      # Returns whether record isn't destroyed.
      def destroyed?
        @destroyed
      end

      # Returns `true` if the record is persisted, i.e. it’s not a new record and
      # it wasn't destroyed, otherwise returns `false`.
      def persisted?
        !(new_record? || destroyed?)
      end

      # Creates an object based on given `values` and saves it to the database, if validation pass.
      #
      # The resulting object is return whether it was saved to the database or not.
      #
      # ```
      # Contact.create({:name => "Jennifer"})
      # Contact.create({name: "Jennifer"})
      # ```
      def self.create(values : Hash | NamedTuple)
        o = new(values)
        o.save
        o
      end

      # Similar to `.create` but yields initialized object to the block before save it.
      #
      # ```
      # User.create({:first_name => "Jennifer"}) do |user|
      #   user.last_name = "Doe"
      # end
      # ```
      def self.create(values : Hash | NamedTuple, &)
        o = new(values)
        yield o
        o.save
        o
      end

      # Creates an object based on an empty hash and saves it to the database, if validation pass.
      #
      # The resulting object is return whether it was saved to the database or not.
      #
      # ```
      # Contact.create
      # ```
      def self.create
        o = new({} of String => DBAny)
        o.save
        o
      end

      # Similar to `.create` but yields initialized object to the block before save it.
      #
      # ```
      # User.create do |user|
      #   user.last_name = "Doe"
      # end
      # ```
      def self.create(&)
        o = new({} of String => DBAny)
        yield o
        o.save
        o
      end

      # Creates an object based on `values` and saves it to the database, if validation pass.
      #
      # The resulting object is return whether it was saved to the database or not.
      #
      # ```
      # Contact.create(name: "Jennifer")
      # ```
      def self.create(**values)
        o = new(values)
        o.save
        o
      end

      # Similar to `.create` but yields initialized object to the block before save it.
      #
      # ```
      # User.create(name: "Jennifer") do |user|
      #   user.last_name = "Doe"
      # end
      # ```
      def self.create(**values, &)
        o = new(values)
        yield o
        o.save
        o
      end

      # Creates an object based on `values` and saves it to the database, if validation pass.
      #
      # Raises an `RecordInvalid` error if validation fail, unlike `.create`.
      #
      # ```
      # Contact.create!({:name => "Jennifer"})
      # Contact.create!({name: "Jennifer"})
      # ```
      def self.create!(values : Hash | NamedTuple)
        o = new(values)
        o.save!
        o
      end

      # Similar to `.create!` but yields initialized object to the block before save it.
      #
      # ```
      # User.create!({:name => "Jennifer"}) do |user|
      #   user.last_name = "Doe"
      # end
      # ```
      def self.create!(values : Hash | NamedTuple, &)
        o = new(values)
        yield o
        o.save!
        o
      end

      # Creates an object based on empty hash and saves it to the database, if validation pass.
      #
      # Raises an `RecordInvalid` error if validation fail, unlike `.create`.
      #
      # ```
      # Contact.create!
      # ```
      def self.create!
        o = new({} of Symbol => DBAny)
        o.save!
        o
      end

      # Similar to `.create!` but yields initialized object to the block before save it.
      #
      # ```
      # User.create! do |user|
      #   user.last_name = "Doe"
      # end
      # ```
      def self.create!(&)
        o = new({} of Symbol => DBAny)
        yield o
        o.save!
        o
      end

      # Creates an object based on `values` and saves it to the database, if validation pass.
      #
      # Raises an `RecordInvalid` error if validation fail, unlike `.create`.
      #
      # ```
      # Contact.create!(name: "Jennifer")
      # ```
      def self.create!(**values)
        o = new(values)
        o.save!
        o
      end

      # Similar to `.create!` but yields initialized object to the block before save it.
      #
      # ```
      # User.create!(name: "Jennifer") do |user|
      #   user.last_name = "Doe"
      # end
      # ```
      def self.create!(**values, &)
        o = new(values)
        yield o
        o.save!
        o
      end

      # Returns array of all non-abstract subclasses of *Jennifer::Model::Base*.
      #
      # ```
      # Jennifer::Model::Base.models # => [Contact, Address, User]
      # ```
      def self.models
        {% begin %}
          {% models = @type.all_subclasses.select { |klass| !klass.abstract? } %}
          {% if !models.empty? %}
            [
              {% for model in models %}
                ::{{model.name}},
              {% end %}
            ]
          {% else %}
            [] of ::Jennifer::Model::Base.class
          {% end %}
        {% end %}
      end

      # Alias for `.new`.
      def self.build(values : DB::ResultSet)
        new(values)
      end

      def self.coercer
        Coercer
      end

      # Return `Jennifer::QueryBuilder::Criteria` for primary column or raises a `Jennifer::AbstractMethod`
      def self.primary
        raise AbstractMethod.new(:primary, {{@type}})
      end

      # Return primary field name or raises a `Jennifer::AbstractMethod`
      def self.primary_field_name
        raise AbstractMethod.new(:primary_field_name, {{@type}})
      end

      # Sets *name* field with *value*
      #
      # ```
      # contact.set_attribute(:name, "Ivan")
      # ```
      abstract def set_attribute(name : String | Symbol, value : AttrType)

      # Assigns record properties based on key-value pairs of *values* and stores them directly to the database
      # without running validations and callbacks.
      #
      # *updated_at* property is not updated as well.
      #
      # If at least one attribute get value of wrong type or attribute is missing or is virtual -
      # `BaseException` is raised.
      #
      # ```
      # user.update_columns({:name => "Jennifer"})
      # ```
      abstract def update_columns(values : Hash(String | Symbol, AttrType))

      # Returns whether any field was changed. If field again got first value - `true` anyway
      # will be returned.
      #
      # ```
      # user.name # => John
      # user.name = "Bill"
      # user.changed? # => true
      # user.name = "John"
      # user.changed? # => true
      # ```
      abstract def changed? : Bool

      # Deletes object from db and calls all related callbacks.
      #
      # It returns `true` if the object was successfully deleted.
      #
      # ```
      # Contact.first!.destroy # => true
      # ```
      abstract def destroy : Bool

      # Returns named tuple of all fields should be saved (because they are changed).
      #
      # NOTE: internal method
      abstract def arguments_to_save

      # Returns named tuple of all model fields to insert.
      #
      # NOTE: internal method
      abstract def arguments_to_insert

      # Hash of changed columns and their new values.
      abstract def changes_before_typecast : Hash(String, Jennifer::DBAny)

      abstract def destroy_without_transaction

      # Return primary field value or raises a `Jennifer::AbstractMethod`
      abstract def primary

      # :nodoc:
      abstract def init_primary_field(value)

      private abstract def save_record_under_transaction(skip_validation)
      private abstract def init_attributes(values : Hash)
      private abstract def init_attributes(values : DB::ResultSet)
      private abstract def __refresh_changes
      private abstract def __refresh_relation_retrieves
      private abstract def store_record : Bool
      private abstract def update_record : Bool

      # Sets attributes based on given *values* using `#set_attribute`
      # and saves it to the database, if validation pass.
      #
      # Returns whether object is successfully saved.
      #
      # ```
      # contact.update({:name => "Jennifer"})
      # contact.update({name: "Jennifer"})
      # ```
      def update(values : Hash | NamedTuple) : Bool
        set_attributes(values)
        save
      end

      # Sets attributes based on given *values* using `#set_attribute`
      # and saves it to the database, if validation pass.
      #
      # Returns whether object is successfully saved.
      #
      # ```
      # contact.update(name: "Jennifer")
      # ```
      def update(**values)
        update(values)
      end

      # Sets attributes based on given *values* and saves it to the database, if validation pass.
      #
      # Raises an `RecordInvalid` error if validation fail, unlike `#update`.
      #
      # ```
      # contact.update!({:name => "Jennifer"})
      # contact.update!({name: "Jennifer"})
      # ```
      def update!(values : Hash | NamedTuple) : Bool
        set_attributes(values)
        save!
      end

      # Sets attributes based on given *values* and saves it to the database, if validation pass.
      #
      # Raises an `RecordInvalid` error if validation fail, unlike `#update`.
      #
      # ```
      # contact.update!(name: "Jennifer")
      # ```
      def update!(**values) : Bool
        update!(values)
      end

      # Sets attributes based on `values` where keys are attribute names.
      #
      # ```
      # post.set_attributes({:title => "New Title", :created_at => Time.local})
      # post.set_attributes({title: "New Title", created_at: Time.local})
      # post.set_attributes(title: "New Title", created_at: Time.local)
      # ```
      def set_attributes(values : Hash | NamedTuple)
        values.each { |k, v| set_attribute(k, v) }
      end

      # :ditto:
      def set_attributes(**values)
        set_attributes(values)
      end

      # Sets *value* to field with name *name* and stores them directly to the database without
      # any validation or callback.
      #
      # Is a shorthand for `#update_columns({ name => value })`.
      # Doesn't use attribute writer.
      def update_column(name : String | Symbol, value : Jennifer::DBAny)
        update_columns({name => value})
      end

      # Saves the object.
      #
      # If the object is a new record it is created in the database, otherwise the existing record get updated.
      #
      # `#save!` always triggers validations. If any of them fails `Jennifer::RecordInvalid` gets raised.
      #
      # There is a series of callbacks associated with `#save!`. If any of the `before_*` callbacks return `false`
      # the action is cancelled and exception is raised. See `Jennifer::Model::Callback` for further details.
      #
      # ```
      # user.name = "Will"
      # user.save! # => true
      # ```
      def save!
        raise Jennifer::RecordInvalid.new(errors.to_a) unless save(false)

        true
      end

      # Saves the object.
      #
      # If the object is a new record it is created in the database, otherwise the existing record get updated.
      #
      # By default, `#save` triggers validations but they can be skipped passing `true` as the second argument.
      # If any of them fails `#save` returns `false`.
      #
      # There is a series of callbacks associated with `#save`. If any of the `before_*` callbacks return `false`
      # the action is cancelled and `false` is returned. See `Jennifer::Model::Callback` for further details.
      #
      # ```
      # user.name = "Will"
      # user.save # => true
      # ```
      def save(skip_validation : Bool = false) : Bool
        return save_record_under_transaction(skip_validation) if self.class.write_adapter.under_transaction?

        self.class.transaction { save_record_under_transaction(skip_validation) } || false
      end

      # Saves all changes to the database without starting a transaction; if any validation fails - returns `false`.
      def save_without_transaction(skip_validation : Bool = false) : Bool
        return false unless skip_validation || validate!
        return false unless __before_save_callback

        response = new_record? ? store_record : update_record
        __after_save_callback
        response
      end

      # Perform destroy without starting a database transaction.
      def destroy_without_transaction
        return false if new_record? || !__before_destroy_callback

        if delete
          @destroyed = true
          __after_destroy_callback
        end
        @destroyed
      end

      # Deletes object from the database.
      #
      # Any callback is invoked. Doesn't start any transaction.
      def delete
        return if new_record? || invalid?

        this = self
        self.class.all.where { this.class.primary == this.primary }.delete
      end

      # Lock current object in the database.
      def lock!(type : String | Bool = true)
        this = self
        self.class.all.where { this.class.primary == this.primary }.lock(type).to_a
      end

      # Starts a transaction and locks current object.
      def with_lock(type : String | Bool = true, &)
        self.class.transaction do |t|
          self.lock!(type)
          yield(t)
        end
      end

      private def update_record : Bool
        return false unless __before_update_callback
        return true unless changed?

        track_timestamps_on_update
        res = self.class.write_adapter.update(self)
        __after_update_callback
        res.rows_affected == 1
      end

      private def store_record : Bool
        return false unless __before_create_callback

        track_timestamps_on_create
        res = self.class.write_adapter.insert(self)
        init_primary_field(res.last_insert_id.as(Int)) if primary.nil? && res.last_insert_id > -1
        raise ::Jennifer::BaseException.new("Record hasn't been stored to the db") if res.rows_affected == 0

        @new_record = false
        __after_create_callback
        true
      end

      # Reloads the record from the database.
      #
      # This method finds record by its primary key and modifies the receiver in-place. All relations are
      # refreshed.
      #
      # ```
      # user = User.first!
      # user.name = "John"
      # user.reload # => #<User id: 1, name: "Will">
      # ```
      def reload
        raise ::Jennifer::RecordNotFound.new("It is not persisted yet") if new_record?

        this = self
        self.class.all.where { this.class.primary == this.primary }.limit(1).each_result_set do |rs|
          init_attributes(rs)
        end
        __refresh_changes
        __refresh_relation_retrieves
        self
      end

      # Performs table lock for current model's table.
      def self.with_table_lock(type : String | Symbol, &)
        write_adapter.with_table_lock(table_name, type.to_s) { |t| yield t }
      end

      # Returns record by given primary field or `nil` otherwise.
      #
      # ```
      # Contact.find(-1) # => nil
      # ```
      def self.find(id)
        all.find(id)
      end

      # Returns record by given primary field or raises `Jennifer::RecordNotFound` exception otherwise.
      #
      # ```
      # Contact.find!(-1) # Jennifer::RecordNotFound
      # ```
      def self.find!(id)
        all.find!(id)
      end

      # Destroys records by given ids.
      #
      # All `destroy` callbacks will be invoked for each record. All records are loaded in batches.
      #
      # ```
      # Contact.destroy(1, 2, 3)
      # Contact.destroy([1, 2, 3])
      # ```
      def self.destroy(*ids)
        destroy(ids.to_a)
      end

      # :ditto:
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

      # Deletes records by given ids.
      def self.delete(*ids)
        delete(ids.to_a)
      end

      # :ditto:
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

      # Performs bulk import of given collection.
      #
      # Any callback is ignored.
      #
      # ```
      # User.import([
      #   User.new({name: "John"}),
      #   User.new({name: "Fahad"}),
      # ])
      # ```
      def self.import(collection : Array(self))
        write_adapter.bulk_insert(collection)
      end

      # Performs bulk import of given *collection* while ignoring models that would cause a duplicate value of any `UNIQUE` index on given *unique_fields*.
      #
      # Some RDBMS (like MySQL) doesn't require specifying exact constraint to be violated, therefore *unique_fields* argument by default is `[] of String`.
      #
      # Any callback is ignored.
      #
      # ```
      # Order.create({:uid => 123})
      # Order.upsert([
      #   Order.new({:uid => 123}),
      #   Order.new({:uid => 321}),
      # ])
      # ```
      def self.upsert(collection : Array(self), unique_fields = [] of String)
        write_adapter.upsert(collection, unique_fields)
      end

      def self.upsert(collection : Array(self), unique_fields = %w[], &)
        definition = (with context yield context)
        write_adapter.upsert(collection, unique_fields, definition)
      end

      macro inherited
        ::Jennifer::Model::Validation.inherited_hook
        ::Jennifer::Model::Callback.inherited_hook
        ::Jennifer::Model::RelationDefinition.inherited_hook

        after_save :__refresh_changes

        # :nodoc:
        def self.superclass
          {{@type.superclass}}
        end

        macro finished
          ::Jennifer::Model::Validation.finished_hook
          ::Jennifer::Model::Callback.finished_hook

          # :nodoc:
          def self.relation(name : String)
            RELATIONS[name]
          rescue e : KeyError
            super(name)
          end
        end
      end
    end
  end
end
