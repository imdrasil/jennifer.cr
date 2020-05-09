require "micrate"
require "../spec/config"

module Micrate
  # This overrides are required to specify custom `db_dir`
  def self.db_dir
    "scripts"
  end

  private def self.migrations_by_version
    Dir.entries(migrations_dir)
       .select { |name| File.file?(File.join(migrations_dir, name)) }
       .select { |name| /^\d+_.+\.sql$/ =~ name }
       .map { |name| Migration.from_file(name) }
       .index_by { |migration| migration.version }
  end
end

Micrate::DB.connection_url = Jennifer::Adapter.default_adapter.connection_string(:db)
Micrate::Cli.run
