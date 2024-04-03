require "./mapping"

module Jennifer
  module View
    # Base class for a database [view](https://en.wikipedia.org/wiki/View_(SQL)).
    #
    # The functionality provided by view is close to the one of `Model::Base` but has next limitations:
    #
    # * supports only `after_initialize` callback
    # * doesn't support any relations
    # * has no persistence mechanism
    # * doesn't support virtual attributes
    #
    # ```
    # class FemaleContact < BaseView
    #   mapping({
    #     id:   Primary32,
    #     name: String,
    #     }, false)
    #   end
    # end
    # ```
    abstract class Base < Model::Resource
      include Mapping

      @[JSON::Field(ignore: true)]
      @new_record : Bool = true
      @[JSON::Field(ignore: true)]
      @destroyed : Bool = false

      # Allows registering `after_initialize` callbacks.
      macro after_initialize(*names)
        {% for name in names %}
          {% AFTER_INITIALIZE_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      # Returns view name.
      #
      # An alias for `.table_name`.
      def self.view_name
        table_name
      end

      # Sets view name.
      #
      # An alias for `.table_name(value : String)`.
      def self.view_name(value : String)
        table_name(value)
      end

      # Alias for `.new`.
      def self.build(values : DB::ResultSet)
        new(values)
      end

      # :ditto:
      def self.build(values : Hash | NamedTuple, new_record : Bool)
        build(values)
      end

      def self.i18n_scope
        :views
      end

      # Returns array of all registered views or `[] of Jennifer::View::Base.class` if nothing.
      def self.views
        {% begin %}
          {% if @type.all_subclasses.size > 1 %}
            [{{@type.all_subclasses.join(", ").id}}] - [Jennifer::View::Materialized]
          {% else %}
            [] of Jennifer::View::Base.class
          {% end %}
        {% end %}
      end

      def self.relation(name)
        raise Jennifer::UnknownRelation.new(self, KeyError.new(name))
      end

      # Reloads the record from the database.
      #
      # This method finds record by its primary key and modifies the receiver in-place.
      #
      # ```
      # user = AdminUser.first!
      # user.name = "John"
      # user.reload # => #<AdminUser id: 1, name: "Will">
      # ```
      def reload
        this = self
        self.class.all.where { this.class.primary == this.primary }.limit(1).each_result_set do |rs|
          init_attributes(rs)
        end
        self
      end

      protected def __after_initialize_callback
        true
      end

      macro inherited
        # :nodoc:
        AFTER_INITIALIZE_CALLBACKS = [] of String
        # :nodoc:
        RELATIONS = {} of String => ::Jennifer::Relation::IRelation

        # :nodoc:
        def self.relation(name : String)
          RELATIONS[name]
        rescue e : KeyError
          super(name)
        end

        # :nodoc:
        def self.actual_table_field_count
          # NOTE: override common behavior
          COLUMNS_METADATA.size
        end

        # :nodoc:
        def self.superclass
          {{@type.superclass}}
        end

        macro finished
          # :nodoc:
          protected def __after_initialize_callback
            return false unless super
            \{{AFTER_INITIALIZE_CALLBACKS.join("\n").id}}
            true
          rescue ::Jennifer::Skip
            false
          end
        end
      end
    end
  end
end

require "./materialized"
