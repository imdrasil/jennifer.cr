# Will be used in nearest feature
require "minitest/autorun"
require "./config"
require "./models.cr"
require "./factories.cr"

describe Jennifer do
  before do
    Jennifer::Adapter.adapter.begin_transaction
  end

  after do
    Jennifer::Adapter.adapter.rollback_transaction
  end
end
