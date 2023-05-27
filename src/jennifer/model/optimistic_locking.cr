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
    #   with_optimistic_lock :custom_lock
    #
    #   mapping(
    #     id: {type: Int32, primary: true},
    #     custom_lock: {type: Int32, default: 0},
    #   )
    # end
    # ```
    macro with_optimistic_lock(locking_column = lock_version)
      {% locking_column = locking_column.id %}

      {% if locking_column != "lock_version".id %}
        def lock_version
          {{locking_column}}
        end

        def self._lock_version
          _{{locking_column}}
        end
      {% end %}

      # :nodoc:
      def destroy_without_transaction
        return false if new_record? || !__before_destroy_callback

        this = self
        res = self.class.all
          .where { (this.class.primary == this.primary) & (this.class._lock_version == this.lock_version) }
          .delete
        raise ::Jennifer::StaleObjectError.new(self) if !res.nil? && res.rows_affected != 1

        if res
          @destroyed = true
          __after_destroy_callback
        end
        @destroyed
      end

      private def increase_lock_version
        self.{{locking_column}} = {{locking_column}} + 1
      end

      private def reset_lock_version
        return @{{locking_column}} unless @{{locking_column}}_changed
        @{{locking_column}}_changed = false
        @{{locking_column}} -= 1
      end

      private def update_record : Bool
        return false unless __before_update_callback
        return true unless changed?

        previous_lock_value = lock_version
        track_timestamps_on_update
        increase_lock_version

        this = self
        res = self.class.all
          .where { (this.class.primary == this.primary) & (this.class._lock_version == previous_lock_value) }
          .update(changes_before_typecast)
        __after_update_callback
        raise ::Jennifer::StaleObjectError.new(self) if !res.nil? && res.rows_affected != 1

        true
      rescue e : Exception
        reset_lock_version
        raise e
      end
    end
  end
end
