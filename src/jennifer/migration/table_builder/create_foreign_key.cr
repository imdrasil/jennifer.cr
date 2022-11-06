require "openssl"

module Jennifer
  module Migration
    module TableBuilder
      class CreateForeignKey < Base
        getter from_table : String, to_table : String, column : String, primary_key : String, on_update : Symbol, on_delete : Symbol

        def initialize(adapter, @from_table, @to_table, column, primary_key, name, @on_update, @on_delete)
          @column = self.class.column_name(@to_table, column)
          @primary_key = (primary_key || "id").to_s
          super(adapter, self.class.foreign_key_name(@from_table, @column, name))
        end

        def process
          schema_processor.add_foreign_key(from_table, to_table, column, primary_key, name, on_update, on_delete)
        end

        def explain
          "add_foreign_key :#{@from_table}, :#{@to_table}, :#{@column}, :#{@primary_key}, \"#{@name}\""
        end

        # :nodoc:
        def self.foreign_key_name(from_table : String | Symbol, column, name : String?) : String
          name ||
            begin
              hashed_identifier = hexdigest("#{from_table}_#{column}_fk")
              "fk_cr_#{hashed_identifier[0...10]}"
            end
        end

        # :nodoc:
        def self.column_name(to_table, name) : String
          (name || Wordsmith::Inflector.foreign_key(Wordsmith::Inflector.singularize(to_table))).not_nil!.to_s
        end

        private def self.hexdigest(text)
          alg = OpenSSL::Digest.new("SHA256")
          alg.update(text)
          alg.final.hexstring
        end
      end
    end
  end
end
