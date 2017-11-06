require "../spec_helper"

class ModelExposingConfig < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true}
  )
  def self.validate_adapter_using_config(expected)
    actual = self.adapter.config.key
    raise "Expected model adapter to use database #{expected} but was #{actual}" unless actual == expected
  end
end

class ModelUsingDefault < ModelExposingConfig
end

class ModelUsingOther < ModelExposingConfig
  using_config :other_config
end

describe Jennifer::Adapter::AdapterSelection do
  it "should use the default config when none specified" do
    ModelUsingDefault.validate_adapter_using_config("default")
  end

  it "should use the specified config when explicitly set via using_config" do
    # note other_config is setup in spec config
    default = ModelUsingOther.validate_adapter_using_config("other_config")
  end
end
