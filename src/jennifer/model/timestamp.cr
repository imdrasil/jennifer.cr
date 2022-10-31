module Jennifer::Model
  module Timestamp
    private abstract def track_timestamps_on_update
    private abstract def track_timestamps_on_create

    macro included
      def track_timestamps_on_update; end

      def track_timestamps_on_create; end
    end

    # Adds callbacks for `created_at` and `updated_at` fields.
    #
    # ```
    # class MyModel < Jennifer::Model::Base
    #   with_timestamps
    #
    #   mapping(
    #     id: {type: Int32, primary: true},
    #     created_at: {type: Time, null: true},
    #     updated_at: {type: Time, null: true}
    #   )
    # end
    # ```
    macro with_timestamps(created_at = true, updated_at = true)
      {% if updated_at %}
        def track_timestamps_on_update
          self.updated_at = Time.local(Jennifer::Config.local_time_zone) unless updated_at_changed?
        end
      {% end %}

      def track_timestamps_on_create
        current_time = Time.local(Jennifer::Config.local_time_zone)
        {% if updated_at %}self.updated_at ||= current_time{% end %}
        {% if created_at %}self.created_at ||= current_time{% end %}
      end
    end
  end
end
