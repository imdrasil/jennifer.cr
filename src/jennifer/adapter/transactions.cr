module Jennifer
  module Adapter
    module Transactions
      @transaction : DB::Transaction? = nil
      @locks = {} of UInt64 => DB::Transaction

      def with_connection(&block)
        if @locks.has_key?(Fiber.current.object_id)
          yield @locks[Fiber.current.object_id].connection
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
        if @locks.has_key?(Fiber.current.object_id)
          yield @locks[Fiber.current.object_id]
        else
          conn = @db.checkout
          res = yield conn
          conn.release
          res ? res : false
        end
      end

      def lock_connection(transaction : DB::Transaction)
        @locks[Fiber.current.object_id] = transaction
      end

      def lock_connection(transaction : Nil)
        @locks.delete(Fiber.current.object_id)
      end

      def current_transaction
        @locks[Fiber.current.object_id]?
      end

      def under_transaction?
        @locks.has_key?(Fiber.current.object_id)
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
              Config.logger.debug("TRANSACTION ROLLBACK")
              raise e
            ensure
              lock_connection(previous_transaction)
            end
          end
        end
        res
      end

      # NOTE: designed for test usage
      def begin_transaction
        raise ::Jennifer::BaseException.new("Couldn't manually begin non top level transaction") if current_transaction
        Config.logger.debug("TRANSACTION START")
        lock_connection(@db.checkout.begin_transaction)
      end

      # NOTE: designed for test usage
      def rollback_transaction
        t = current_transaction
        raise ::Jennifer::BaseException.new("No transaction to rollback") unless t
        t = t.not_nil!
        t.rollback
        Config.logger.debug("TRANSACTION ROLLBACK")
        t.connection.release
        lock_connection(nil)
      end
    end
  end
end
