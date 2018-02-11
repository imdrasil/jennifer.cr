require "../../model/callback"

module Jennifer
  module Adapter
    module Observer
      class Base
        getter record : Model::Callback, action : Symbol

        def initialize(@record, @action)
        end

        def dispatch_commit
          case @action
          when :create
            record.__after_create_commit_callback
          when :save
            record.__after_save_commit_callback
          when :destroy
            record.__after_destroy_commit_callback
          end
        end

        def dispatch_rollback
          case @action
          when :create
            record.__after_create_rollback_callback
          when :save
            record.__after_save_rollback_callback
          when :destroy
            record.__after_destroy_rollback_callback
          end
        end
      end
    end
  end
end
