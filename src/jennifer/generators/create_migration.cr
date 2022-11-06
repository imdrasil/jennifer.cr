require "./migration"
require "./field_set"

module Jennifer
  module Generators
    class CreateMigration < Migration
      getter fields : FieldSet

      def initialize(args, @fields)
        super(args)
      end

      def table_name
        Wordsmith::Inflector.pluralize(model_name.downcase)
      end

      def name
        "Create#{table_name.camelcase}"
      end

      private def model_name
        @name
      end

      ECR.def_to_s __DIR__ + "/create_migration.ecr"
    end
  end
end
