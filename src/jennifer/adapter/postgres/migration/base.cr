module Jennifer
  module Migration
    abstract class Base
      def create_enum(name : String | Symbol, values)
        TableBuilder::CreateEnum.new(name, values).process
      end

      def drop_enum(name : String | Symbol)
        TableBuilder::DropEnum.new(name).process
      end

      def change_enum(name : String | Symbol, options)
        TableBuilder::ChangeEnum.new(name, options).process
      end

      def data_type_exists?(name : String | Symbol)
        Adapter.adapter.as(Postgres).data_type_exists?(name)
      end

      def create_materialized_view(name : String | Symbol, source)
        TableBuilder::CreateMaterializedView.new(name, source).process
      end

      def drop_materialized_view(name : String | Symbol)
        TableBuilder::DropMaterializedView.new(name).process
      end
    end
  end
end
