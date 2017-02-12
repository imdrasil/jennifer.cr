require "./jennifer/*"
require "./jennifer/adapter/*"
require "./jennifer/migration/table_builder/*"
require "./jennifer/migration/*"
require "./jennifer/model/*"

module Jennifer
  class StubRelation < ::Jennifer::Model::IRelation
    def table_name
      raise "stubed relation"
    end

    def model_class
      raise "stubed relation"
    end

    def type
      raise "stubed relation"
    end

    def set_callback
      raise "stubed relation"
    end
  end
end
