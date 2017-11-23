require "../spec_helper"

def create_configuration(adapter_name = nil)
  Jennifer::Config.configure(:custom) do |custom|
    if adapter_name
      custom.adapter = adapter_name
    else
      {% if env("DB") == "mysql" %}
        custom.user = ENV["DB_USER"]? || "root"
        custom.adapter = "mysql"
      {% else %}
        custom.user = ENV["DB_USER"]? || "developer"
        custom.password = ENV["DB_PASSWORD"]? || "1qazxsw2"
      {% end %}
    end
    custom.db = "jennifer_test"
  end
end

describe Jennifer::Adapter::AdapterRegistry do
  it "should have packaged adapters registered" do
    # again, TBR when adapters can coexist
    {% if env("DB") == "mysql" %}
      Jennifer::Adapter::AdapterRegistry.adapter_class("mysql").should eq(Jennifer::Adapter::Mysql)
    {% else %}
      Jennifer::Adapter::AdapterRegistry.adapter_class("postgres").should eq(Jennifer::Adapter::Postgres)
    {% end %}
  end

  it "should fail if an unknown adapter is requested" do
    expect_raises(Jennifer::UnknownAdapter, /Unknown adapter someadapter, available adapters are/) do
      create_configuration("someadapter")
      Jennifer::Adapter::AdapterRegistry.adapter(:custom)
    end
  end

  it "should create an instance of a configured adapter" do
    create_configuration
    Jennifer::Adapter::AdapterRegistry.adapter(:custom).should be_a(Jennifer::Adapter::Base)
  end

  it "should always return the same adapter instance once created" do
    create_configuration
    initial = Jennifer::Adapter::AdapterRegistry.adapter(:custom)
    later = Jennifer::Adapter::AdapterRegistry.adapter(:custom)
    later.should eq(initial)
  end
end
