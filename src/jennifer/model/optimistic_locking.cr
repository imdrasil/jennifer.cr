module Jennifer::Model
  module OptimisticLocking
    # Add optimistic locking to model
    # By default, it uses column `lock_version : Int32` as lock
    # The column used as lock must be type `Int32` or `Int64` and the default value of 0
    # You can use a different column name as lock by passing the column name to the method.
    #
    # ```
    # class MyModel < Jennifer::Model::Base
    #   with_optimistic_lock
    #
    #   mapping(
    #     id: {type: Int32, primary: true},
    #     lock_version: {type: Int32, default: 0},
    #   )
    # end
    # ```
    # Or use a custom column name for the locking column:
    # ```
    # class MyModel < Jennifer::Model::Base
    #   with_optimistic_lock(custom_lock)
    #
    #   mapping(
    #     id: {type: Int32, primary: true},
    #     custom_lock: {type: Int32, default: 0},
    #   )
    # end
    # ```
    macro with_optimistic_lock(locking_column = lock_version)
      def self.locking_column
        {{locking_column.stringify}}
      end

      def locking_column
        self.class.locking_column
      end

      {% if locking_column != "lock_version" %}
        def lock_version
          {{locking_column}}
        end

        def self._lock_version
          _{{locking_column}}
        end
      {% end %}

      def increase_lock_version!
        self.{{locking_column}} = {{locking_column}} + 1
      end

      def reset_lock_version!
        @{{locking_column}} -= 1
        @{{locking_column}}_changed = false
      end
    end
  end
end
