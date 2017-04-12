# require "./../model/relation"
require "../model/base"

module Jennifer
  module Migration
    class Version < Model::Base
      table_name "migration_versions"
      mapping(
        id: {type: Int32, primary: true},
        version: String
      )
    end
  end
end
