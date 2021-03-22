require "../spec_helper"

describe Jennifer::Model::Coercer do
  described_class = Jennifer::Model::Coercer

  describe BigDecimal do
    it { described_class.coerce("123.12", BigDecimal?).should eq(BigDecimal.new(12312, 2)) }
  end
end
