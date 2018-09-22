module Jennifer
  module Model
    # Callbacks are hooks into the life cycle of a model object that allow you to trigger logic before
    #  or after an alteration of the object state.
    module Callback
      protected def __before_save_callback
        true
      end

      protected def __before_create_callback
        true
      end

      protected def __before_update_callback
        true
      end

      protected def __before_destroy_callback
        true
      end

      protected def __before_validation_callback
        true
      end

      protected def __after_save_callback
        true
      end

      protected def __after_create_callback
        true
      end

      protected def __after_update_callback
        true
      end

      protected def __after_initialize_callback
        true
      end

      protected def __after_destroy_callback
        true
      end

      protected def __after_validation_callback
        true
      end

      protected def __after_save_commit_callback
        true
      end

      protected def __after_create_commit_callback
        true
      end

      protected def __after_update_commit_callback
        true
      end

      protected def __after_destroy_commit_callback
        true
      end

      protected def __after_save_rollback_callback
        true
      end

      protected def __after_create_rollback_callback
        true
      end

      protected def __after_destroy_rollback_callback
        true
      end

      protected def __after_update_rollback_callback
        true
      end

      # Defines callbacks which are called before `Base.save` (regardless of whether it's a `create` or `update` save).
      #
      # Note that these callbacks are already wrapped in the transaction around save.
      macro before_save(*names)
        {% for name in names %}
          {% CALLBACKS[:save][:before] << name.id.stringify %}
        {% end %}
      end

      # Defines callbacks which are called after `Base.save` (regardless of whether it's a `create` or `update` save).
      #
      # Note that these callbacks are still wrapped in the transaction around save.
      macro after_save(*names)
        {% for name in names %}
          {% CALLBACKS[:save][:after] << name.id.stringify %}
        {% end %}
      end

      # Defines callbacks which are called before `Base.save` on new objects that haven’t been saved yet
      # (no record exists).
      #
      # Note that these callbacks are already wrapped in the transaction around save.
      macro before_create(*names)
        {% for name in names %}
          {% CALLBACKS[:create][:before] << name.id.stringify %}
        {% end %}
      end

      # Defines callbacks which are called after `Base.save` on new objects that haven’t been saved yet
      # (no record exists).
      #
      # Note that these callbacks is still wrapped in the transaction around save.
      macro after_create(*names)
        {% for name in names %}
          {% CALLBACKS[:create][:after] << name.id.stringify %}
        {% end %}
      end

      # Defines callbacks which are called before `Base.save` on existing objects that have a record.
      #
      # Note that these callbacks are already wrapped in the transaction around save.
      macro before_update(*names)
        {% for name in names %}
          {% CALLBACKS[:update][:before] << name.id.stringify %}
        {% end %}
      end

      # Defines callbacks which are called after `Base.save` on existing objects that have a record.
      #
      # Note that these callbacks are still wrapped in the transaction around save.
      macro after_update(*names)
        {% for name in names %}
          {% CALLBACKS[:update][:after] << name.id.stringify %}
        {% end %}
      end

      # Defines callbacks which are called after `Base.build` call.
      macro after_initialize(*names)
        {% for name in names %}
          {% CALLBACKS[:initialize][:after] << name.id.stringify %}
        {% end %}
      end

      # Defines callbacks which are called before `Base.destroy`
      macro before_destroy(*names)
        {% for name in names %}
          {% CALLBACKS[:destroy][:before] << name.id.stringify %}
        {% end %}
      end

      # Defines callbacks which are called after `Base.destroy`.
      macro after_destroy(*names)
        {% for name in names %}
          {% CALLBACKS[:destroy][:after] << name.id.stringify %}
        {% end %}
      end

      # Defines callbacks which are called before `Base.validate!` (which is part of the `Base.save` call).
      macro before_validation(*names)
        {% for name in names %}
          {% CALLBACKS[:validation][:before] << name.id.stringify %}
        {% end %}
      end

      # Defines callbacks which are called after `Base.validate!` (which is part of the `Base.save` call).
      macro after_validation(*names)
        {% for name in names %}
          {% CALLBACKS[:validation][:after] << name.id.stringify %}
        {% end %}
      end

      # Defines callbacks which are called after a record has been created, updated, or destroyed.
      #
      # You can specify that the callback should only be fired by a certain action with the :on option:
      # ```
      # after_commit :var, on: :save
      # after_commit :foo, on: :create
      # after_commit :bar, on: :update
      # after_commit :baz, on: :destroy
      # ```
      macro after_commit(*names, on)
        {% unless [:create, :save, :destroy, :update].includes?(on) %}
          {% raise "#{on} is invalid action for %after_commit callback." %}
        {% end %}
        {% for name in names %}
          {% CALLBACKS[on][:commit] << name %}
        {% end %}
      end

      # Defines callbacks which are called after a create, update, or destroy are rolled back.
      #
      # Please check the documentation of `after_commit` macro for options.
      macro after_rollback(*names, on)
        {% unless [:create, :save, :destroy, :update].includes?(on) %}
          {% raise "#{on} is invalid action for %after_rollback callback." %}
        {% end %}
        {% for name in names %}
          {% CALLBACKS[on][:rollback] << name %}
        {% end %}
      end

      # :nodoc:
      macro inherited_hook
        # :nodoc:
        CALLBACKS = {
          save: {
            before: [] of String,
            after: [] of String,
            commit: [] of String,
            rollback: [] of String
          },
          create: {
            before: [] of String,
            after: [] of String,
            commit: [] of String,
            rollback: [] of String
          },
          update: {
            before: [] of String,
            after: [] of String,
            commit: [] of String,
            rollback: [] of String
          },
          destroy: {
            after: [] of String,
            before: [] of String,
            commit: [] of String,
            rollback: [] of String
          },
          initialize: {
            after: [] of String
          },
          validation: {
            before: [] of String,
            after: [] of String
          }
        }
      end

      # :nodoc:
      macro finished_hook
        {% verbatim do %}
          {% for type in [:before, :after] %}
            {% for action in [:save, :create, :destroy, :validation, :update] %}
              {% if !CALLBACKS[action][type].empty? %}
                protected def __{{type.id}}_{{action.id}}_callback
                  return false unless super
                  {{ CALLBACKS[action][type].join("\n").id }}
                  true
                rescue ::Jennifer::Skip
                  false
                end
              {% end %}
            {% end %}
          {% end %}

          {% for action in ["save", "create", "destroy", "update"] %}
            {% for type in ["commit", "rollback"] %}
              {% constant_name = "HAS_#{action.upcase.id}_#{type.upcase.id}_CALLBACK" %}
              {% if !CALLBACKS[action][type].empty? %}
                # :nodoc:
                {{ "#{constant_name.id} = true".id}}

                protected def __after_{{action.id}}_{{type.id}}_callback
                  return false unless super
                  {{ CALLBACKS[action][type].join("\n").id }}
                  true
                rescue ::Jennifer::Skip
                  false
                end
              {% else %}
                # :nodoc:
                {{ "#{constant_name.id} = false".id}}
              {% end %}
            {% end %}
          {% end %}

          {% if !CALLBACKS[:initialize][:after].empty? %}
            protected def __after_initialize_callback
              return false unless super
              {{ CALLBACKS[:initialize][:after].join("\n").id }}
              true
            rescue ::Jennifer::Skip
              false
            end
          {% end %}
        {% end %}
      end
    end
  end
end
