require "./create_migration"

module Jennifer
  module Generators
    class Model < Base
      getter fields : FieldSet

      def initialize(args)
        super
        @fields = FieldSet.new(definitions)
      end

      def render
        super
        CreateMigration.new(args, fields).render
      end

      private def file_path : String
        File.join(Config.model_files_path.to_s, file_name)
      end

      private def file_name
        "#{name.underscore}.cr"
      end

      private def class_name
        name.camelcase
      end

      ECR.def_to_s __DIR__ + "/model.ecr"
    end
  end
end
