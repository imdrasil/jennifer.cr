module Jennifer
  module Adapter
    class TransactionObserver
      property transaction : DB::Transaction

      @rolled_back = false
      @commit_observers = [] of -> Bool
      @rollback_observers = [] of -> Bool

      delegate connection, to: transaction

      def initialize(@transaction)
      end

      def rollback
        @rolled_back = true
      end

      def observe_commit(block)
        @commit_observers << block
      end

      def observe_rollback(block)
        @rollback_observers << block
      end

      def update
        if @rolled_back
          @rollback_observers.each(&.call)
        else
          @commit_observers.each(&.call)
        end
      end
    end
  end
end
