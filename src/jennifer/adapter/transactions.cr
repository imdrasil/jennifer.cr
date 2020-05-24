require "./transaction_observer"

module Jennifer
  module Adapter
    module Transactions
      @locks = {} of UInt64 => TransactionObserver

      # Yields current connection or checkout a new one.
      def with_connection(&block)
        if under_transaction?
          yield @locks[fiber_id].connection
        else
          with_manual_connection { |conn| yield conn }
        end
      end

      # Yields new checkout connection.
      def with_manual_connection(&block)
        conn = db.checkout
        begin
          yield conn
        ensure
          conn.release
        end
      end

      # Returns current transaction or `nil`.
      def current_transaction
        @locks[fiber_id]?.try(&.transaction)
      end

      # Returns whether current context has opened transaction.
      def under_transaction?
        @locks.has_key?(fiber_id)
      end

      # Starts a transaction and yields it to the given block.
      def transaction(&block)
        previous_transaction = current_transaction
        res = nil
        with_transactionable do |conn|
          conn.transaction do |tx|
            lock_connection(tx)
            begin
              Config.logger.debug { "BEGIN" }
              res = yield(tx)
              Config.logger.debug { "COMMIT" }
            rescue e
              @locks[fiber_id].rollback
              Config.logger.debug { "ROLLBACK" }
              raise e
            ensure
              lock_connection(previous_transaction)
            end
          end
        end
        res
      end

      # Subscribes given *block* to `commit` current transaction event.
      def subscribe_on_commit(block : -> Bool)
        @locks[fiber_id].observe_commit(block)
      end

      # Subscribes given *block* to `rollback` current transaction event.
      def subscribe_on_rollback(block : -> Bool)
        @locks[fiber_id].observe_rollback(block)
      end

      # Starts manual transaction for current fiber. Designed for usage in test callback.
      def begin_transaction
        raise ::Jennifer::BaseException.new("Couldn't manually begin non top level transaction") if current_transaction

        Config.logger.debug { "START" }
        lock_connection(db.checkout.begin_transaction)
      end

      # Closes manual transaction for current fiber. Designed for usage in test callback.
      def rollback_transaction
        t = current_transaction
        raise ::Jennifer::BaseException.new("No transaction to rollback") unless t

        t = t.not_nil!
        t.rollback
        Config.logger.debug { "ROLLBACK" }
        t.connection.release
        lock_connection(nil)
      end

      @[AlwaysInline]
      private def fiber_id
        Fiber.current.object_id
      end

      private def lock_connection(transaction : DB::Transaction)
        if under_transaction?
          @locks[fiber_id].transaction = transaction
        else
          @locks[fiber_id] = TransactionObserver.new(transaction)
        end
      end

      private def lock_connection(transaction : Nil)
        @locks[fiber_id].update
        @locks.delete(fiber_id)
      end

      # Yields current transaction or starts a new one.
      private def with_transactionable(&block)
        if under_transaction?
          yield @locks[fiber_id].transaction
        else
          conn = db.checkout
          begin
            res = yield conn
          ensure
            conn.release
          end
          res || false
        end
      end
    end
  end
end
