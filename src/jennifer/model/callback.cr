module Jennifer
  module Model
    module Callback
      macro before_save(*names)
        {% for name in names %}
          {% BEFORE_SAVE_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro after_save(*names)
        {% for name in names %}
          {% AFTER_SAVE_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro before_create(*names)
        {% for name in names %}
          {% BEFORE_CREATE_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro after_create(*names)
        {% for name in names %}
          {% AFTER_CREATE_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro after_initialize(*names)
        {% for name in names %}
          {% AFTER_INITIALIZE_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro before_destroy(*names)
        {% for name in names %}
          {% BEFORE_DESTROY_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro after_destroy(*names)
        {% for name in names %}
          {% AFTER_DESTROY_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro before_validation(*names)
        {% for name in names %}
          {% BEFORE_VALIDATION_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro after_validation(*names)
        {% for name in names %}
          {% AFTER_VALIDATION_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro inherited_hook
        BEFORE_SAVE_CALLBACKS = [] of String
        AFTER_SAVE_CALLBACKS = [] of String
        BEFORE_CREATE_CALLBACKS = [] of String
        AFTER_CREATE_CALLBACKS = [] of String
        AFTER_INITIALIZE_CALLBACKS = [] of String
        BEFORE_DESTROY_CALLBACKS = [] of String
        AFTER_DESTROY_CALLBACKS = [] of String
        BEFORE_VALIDATION_CALLBACKS = [] of String
        AFTER_VALIDATION_CALLBACKS = [] of String
      end

      macro finished_hook
        def __before_save_callback
          \{% for method in BEFORE_SAVE_CALLBACKS %}
            \{{method.id}}
          \{% end %}
          true
        rescue ::Jennifer::Skip
          false
        end

        def __after_save_callback
          \{% for method in AFTER_SAVE_CALLBACKS %}
            \{{method.id}}
          \{% end %}
        rescue ::Jennifer::Skip
        end

        def __before_create_callback
          \{% for method in BEFORE_CREATE_CALLBACKS %}
            \{{method.id}}
          \{% end %}
          true
        rescue ::Jennifer::Skip
          false
        end

        def __after_create_callback
          \{% for method in AFTER_CREATE_CALLBACKS %}
            \{{method.id}}
          \{% end %}
        rescue ::Jennifer::Skip
        end

        def __after_initialize_callback
          \{% for method in AFTER_INITIALIZE_CALLBACKS %}
            \{{method.id}}
          \{% end %}
        rescue ::Jennifer::Skip
        end

        def __before_destroy_callback
          \{% for method in BEFORE_DESTROY_CALLBACKS %}
            \{{method.id}}
          \{% end %}
          true
        rescue ::Jennifer::Skip
          false
        end

        def __after_destroy_callback
          \{% for method in AFTER_DESTROY_CALLBACKS %}
            \{{method.id}}
          \{% end %}
        rescue ::Jennifer::Skip
        end

        def __before_validation_callback
          \{% for method in BEFORE_VALIDATION_CALLBACKS %}
            \{{method.id}}
          \{% end %}
          true
        rescue ::Jennifer::Skip
          false
        end

        def __after_validation_callback
          \{% for method in AFTER_VALIDATION_CALLBACKS %}
            \{{method.id}}
          \{% end %}
        rescue ::Jennifer::Skip
        end
      end
    end
  end
end
