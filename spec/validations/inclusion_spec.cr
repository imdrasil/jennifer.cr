require "../spec_helper"

describe Jennifer::Validations::Inclusion do
  described_class = Jennifer::Validations::Inclusion

  describe ".validate" do
    it do
      instance = Factory.build_contact
      described_class.validate(instance, :name, "John", false, ["Sam"])
      instance.should be_valid
    end

    it do
      instance = Factory.build_contact
      described_class.validate(instance, :name, nil, true, [1.2])
      instance.should be_valid
    end
  end
end
