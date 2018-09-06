require "./transaction_observer"

module Jennifer
  module Adapter
    module Transactions
      @locks = {} of UInt64 => TransactionObserver

      def with_connection(&block)
        if under_transaction?
          yield @locks[fiber_id].connection
        else
          conn = @db.checkout
          res = yield conn
          conn.release
          res
        end
      end

      def with_manual_connection(&block)
        conn = @db.checkout
        res = yield conn
        conn.release
        res
      end

      def with_transactionable(&block)
        if under_transaction?
          yield @locks[fiber_id].transaction
        else
          conn = @db.checkout
          begin
            res = yield conn
          ensure
            conn.release
          end
          res || false
        end
      end

      def lock_connection(transaction : DB::Transaction)
        if @locks[fiber_id]?
          @locks[fiber_id].transaction = transaction
        else
          @locks[fiber_id] = TransactionObserver.new(transaction)
        end
      end

      def lock_connection(transaction : Nil)
        @locks[fiber_id].update
        @locks.delete(fiber_id)
      end

      def current_transaction
        @locks[fiber_id]?.try(&.transaction)
      end

      def under_transaction?
        @locks.has_key?(fiber_id)
      end

      def transaction(&block)
        previous_transaction = current_transaction
        res = nil
        with_transactionable do |conn|
          conn.transaction do |tx|
            lock_connection(tx)
            begin
              Config.logger.debug("TRANSACTION START")
              res = yield(tx)
              Config.logger.debug("TRANSACTION COMMIT")
            rescue e
              @locks[fiber_id].rollback
              Config.logger.debug("TRANSACTION ROLLBACK")
              raise e
            ensure
              lock_connection(previous_transaction)
            end
          end
        end
        res
      end

      def subscribe_on_commit(block : -> Bool)
        @locks[fiber_id].observe_commit(block)
      end

      def subscribe_on_rollback(block : -> Bool)
        @locks[fiber_id].observe_rollback(block)
      end

      # Starts manual transaction for current fiber. Designed as test case isolating method.
      def begin_transaction
        raise ::Jennifer::BaseException.new("Couldn't manually begin non top level transaction") if current_transaction
        Config.logger.debug("TRANSACTION START")
        lock_connection(@db.checkout.begin_transaction)
      end

      # Closes manual transaction for current fiber. Designed as test case isolating method.
      def rollback_transaction
        t = current_transaction
        raise ::Jennifer::BaseException.new("No transaction to rollback") unless t
        t = t.not_nil!
        t.rollback
        Config.logger.debug("TRANSACTION ROLLBACK")
        t.connection.release
        lock_connection(nil)
      end

      @[AlwaysInline]
      private def fiber_id
        Fiber.current.object_id
      end
    end
  end
end
