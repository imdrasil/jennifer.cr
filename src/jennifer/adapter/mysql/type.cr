struct MySql::Type
  def self.type_for(t : ::JSON::Any.class)
    MySql::Type::Json
  end

  decl_type Json, 0xF5u8, ::String do
    def self.write(packet, v : ::String)
      packet.write_lenenc_string v
    end

    def self.write(packet, v : ::JSON::Any)
      packet.write_lenenc_string v.to_json
    end

    def self.read(packet)
      packet.read_lenenc_string
    end

    def self.parse(str : ::String)
      str
    end
  end
end
