struct Char
  def to_json(json : JSON::Builder)
    json.string(self.to_s)
  end

  def to_json_object_key
    self.to_s
  end
end

struct Time::Span
  def to_json(json : JSON::Builder)
    json.string(self.to_s)
  end

  def to_json_object_key
    self.to_s
  end
end

struct Slice
  def to_json(json : JSON::Builder)
    json.string(self.to_s)
  end

  def to_json_object_key
    self.to_s
  end
end

struct UUID
  def to_json(json : JSON::Builder)
    json.string(self.to_s)
  end

  def to_json_object_key
    self.to_s
  end
end
