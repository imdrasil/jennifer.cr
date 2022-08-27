module Jennifer::Model
  module Querying
    {% for method in %i[
                       where select from union distinct order group with merge limit offset lock reorder
                       count max min sum avg group_count group_max group_min group_sum group_avg
                       with_relation includes preload eager_load
                       last last! first first! find_by find_by! pluck exists? increment decrement ids find_records_by_sql
                     ] %}
      # Is a shortcut for `.all.{{method.id}}`
      def {{method.id}}(*args, **opts)
        all.{{method.id}}(*args, **opts)
      end
    {% end %}

    {% for method in %i[where select having group order reorder] %}
      # Is a shortcut for `.all.{{method.id}}`
      def {{method.id}}(&block)
        all.{{method.id}} { |*yield_args| with yield_args[0] yield *yield_args }
      end
    {% end %}

    {% for method in %i[find_in_batches find_each] %}
      # Is a shortcut for `.all.{{method.id}}`
      def {{method.id}}(*args, **opts, &block)
        all.{{method.id}}(*args, **opts) { |*yield_args| yield *yield_args }
      end
    {% end %}

    {% for method in %i[join right_join left_join lateral_join] %}
      # Is a shortcut for `.all.{{method.id}}`
      def {{method.id}}(*args, **opts, &block)
        all.{{method.id}}(*args, **opts) { |*yield_args| with yield_args[1] yield *yield_args }
      end
    {% end %}
  end
end
