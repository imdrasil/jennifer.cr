module Jennifer
  module Model
    module Callback
      def __before_save_callback
        true
      end

      def __before_create_callback
        true
      end

      def __before_update_callback
        true
      end

      def __before_destroy_callback
        true
      end

      def __before_validation_callback
        true
      end

      def __after_save_callback
        true
      end

      def __after_create_callback
        true
      end

      def __after_update_callback
        true
      end

      def __after_initialize_callback
        true
      end

      def __after_destroy_callback
        true
      end

      def __after_validation_callback
        true
      end

      def __after_save_commit_callback
        true
      end

      def __after_create_commit_callback
        true
      end

      def __after_update_commit_callback
        true
      end

      def __after_destroy_commit_callback
        true
      end

      def __after_save_rollback_callback
        true
      end

      def __after_create_rollback_callback
        true
      end

      def __after_destroy_rollback_callback
        true
      end

      def __after_update_rollback_callback
        true
      end

      macro before_save(*names)
        {% for name in names %}
          {% CALLBACKS[:save][:before] << name.id.stringify %}
        {% end %}
      end

      macro after_save(*names)
        {% for name in names %}
          {% CALLBACKS[:save][:after] << name.id.stringify %}
        {% end %}
      end

      macro before_create(*names)
        {% for name in names %}
          {% CALLBACKS[:create][:before] << name.id.stringify %}
        {% end %}
      end

      macro after_create(*names)
        {% for name in names %}
          {% CALLBACKS[:create][:after] << name.id.stringify %}
        {% end %}
      end

      macro before_update(*names)
        {% for name in names %}
          {% CALLBACKS[:update][:before] << name.id.stringify %}
        {% end %}
      end

      macro after_update(*names)
        {% for name in names %}
          {% CALLBACKS[:update][:after] << name.id.stringify %}
        {% end %}
      end

      macro after_initialize(*names)
        {% for name in names %}
          {% CALLBACKS[:initialize][:after] << name.id.stringify %}
        {% end %}
      end

      macro before_destroy(*names)
        {% for name in names %}
          {% CALLBACKS[:destroy][:before] << name.id.stringify %}
        {% end %}
      end

      macro after_destroy(*names)
        {% for name in names %}
          {% CALLBACKS[:destroy][:after] << name.id.stringify %}
        {% end %}
      end

      macro before_validation(*names)
        {% for name in names %}
          {% CALLBACKS[:validation][:before] << name.id.stringify %}
        {% end %}
      end

      macro after_validation(*names)
        {% for name in names %}
          {% CALLBACKS[:validation][:after] << name.id.stringify %}
        {% end %}
      end

      macro after_commit(*names, on)
        {% unless [:create, :save, :destroy, :update].includes?(on) %}
          {% raise "#{on} is invalid action for %after_commit callback." %}
        {% end %}
        {% for name in names %}
          {% CALLBACKS[on][:commit] << name %}
        {% end %}
      end

      macro after_rollback(*names, on)
        {% unless [:create, :save, :destroy, :update].includes?(on) %}
          {% raise "#{on} is invalid action for %after_rollback callback." %}
        {% end %}
        {% for name in names %}
          {% CALLBACKS[on][:rollback] << name %}
        {% end %}
      end

      macro inherited_hook
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

      macro finished_hook
        {% verbatim do %}
          {% for type in [:before, :after] %}
            {% for action in [:save, :create, :destroy, :validation, :update] %}
              {% if !CALLBACKS[action][type].empty? %}
                def __{{type.id}}_{{action.id}}_callback
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
                {{ "#{constant_name.id} = true".id}}

                def __after_{{action.id}}_{{type.id}}_callback
                  return false unless super
                  {{ CALLBACKS[action][type].join("\n").id }}
                  true
                rescue ::Jennifer::Skip
                  false
                end
              {% else %}
                {{ "#{constant_name.id} = false".id}}
              {% end %}
            {% end %}
          {% end %}

          {% if !CALLBACKS[:initialize][:after].empty? %}
            def __after_initialize_callback
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
