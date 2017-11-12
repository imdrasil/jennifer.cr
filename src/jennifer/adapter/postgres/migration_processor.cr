require "../migration_processor"

module Jennifer
  module Postgres
    class MigrationProcessor < Adapter::MigrationProcessor
      delegate data_type_exists?, to: adapter.as(Postgres)

      def create_enum(name : String | Symbol, values)
        Migration::TableBuilder::CreateEnum.new(name, values).process
      end

      def drop_enum(name : String | Symbol)
        Migration::TableBuilder::DropEnum.new(name).process
      end

      def change_enum(name : String | Symbol, options)
        Migration::TableBuilder::ChangeEnum.new(name, options).process
      end

      def create_materialized_view(name : String | Symbol, _as)
        Migration::TableBuilder::CreateMaterializedView.new(name, _as).process
      end

      def drop_materialized_view(name : String | Symbol)
        Migration::TableBuilder::DropMaterializedView.new(name).process
      end
    end
  end
end
