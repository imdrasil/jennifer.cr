module Jennifer::Model
  module OptimisticLocking
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
      {% end %}

      def increment_lock_version!
        self.{{locking_column}} = {{locking_column}} + 1
      end

      def reset_lock_version!
        @{{locking_column}} -= 1
        @{{locking_column}}_changed = false
      end
    end
  end
end
