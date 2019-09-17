require "./base"

module Jennifer
  module Generators
    class Migration < Base
      # Migration file name timestamp format.
      DATE_FORMAT = "%Y%m%d%H%M%S%L"

      private def file_path : String
        File.join(Config.migration_files_path.to_s, file_name)
      end

      private def file_name
        time = Time.local.to_s(DATE_FORMAT)
        "#{time}_#{name.underscore}.cr"
      end

      private def class_name
        name.camelcase
      end

      ECR.def_to_s __DIR__ + "/migration.ecr"
    end
  end
end
