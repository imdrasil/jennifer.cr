require "../spec_helper"

describe Jennifer::Validations::Inclusion do
  described_class = Jennifer::Validations::Inclusion

  describe ".validate" do
    it do
      c = Factory.build_contact
      described_class.instance.validate(c, :name, "John", false, ["Sam"])
      c.should be_valid
    end

    it do
      instance = Factory.build_contact
      described_class.instance.validate(instance, :name, nil, true, [1.2])
      instance.should be_valid
    end
  end
end
