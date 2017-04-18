require "json"

struct MySql::Type
  alias JsonType = ::JSON::Any | ::JSON::Type

  def self.type_for(t : JsonType.class)
    MySql::Type::Json
  end

  decl_type Json, 0xF5u8, ::String do
    def self.write(packet, v : JsonType)
      packet.write_lenenc_string v.to_json
    end

    def self.read(packet)
      ::JSON.parse(packet.read_lenenc_string)
    end

    def self.parse(str : ::String)
      ::JSON.parse(str)
    end
  end
end
