require "../spec_helper"

class Spec::TestClassForError
  include Jennifer::Model::Translation

  def self.superclass; end
end

describe Jennifer::Model::Errors do
  # TODO: add test case descriptions

  described_class = Jennifer::Model::Errors
  facebook_profile = Factory.build_facebook_profile

  describe ".new" do
    context "with custom class" do
      it do
        described_class.new(Spec::TestClassForError.new).base.is_a?(Spec::TestClassForError).should be_true
      end
    end
  end

  describe "#include?" do
    errors = described_class.new(facebook_profile)
    errors.add(:uid)

    it { errors.include?(:uid).should be_true }
    it { errors.include?(:name).should be_false }
  end

  describe "#clear" do
    it do
      errors = described_class.new(facebook_profile)
      errors.add(:uid)
      errors.clear
      errors.empty?.should be_true
    end
  end

  describe "#delete" do
    it do
      errors = described_class.new(facebook_profile)
      errors.add(:uid)
      errors.add(:id)
      errors.delete(:id)
      errors.keys.should eq([:uid])
    end
  end

  describe "#[]" do
    context "with existing key" do
      it do
        errors = described_class.new(facebook_profile)
        errors.add(:uid, "some message")
        errors.add(:uid, :exclusion)
        errors[:uid].should eq(["some message", "is reserved"])
      end
    end

    context "without key" do
      it do
        errors = described_class.new(facebook_profile)
        errors.add(:uid, "some message")
        errors[:id].should eq([] of String)
      end
    end
  end

  describe "#[]?" do
    context "with existing key" do
      it do
        errors = described_class.new(facebook_profile)
        errors.add(:uid, "some message")
        errors.add(:uid, :exclusion)
        errors[:uid]?.should eq(["some message", "is reserved"])
      end
    end

    context "without key" do
      it do
        errors = described_class.new(facebook_profile)
        errors.add(:uid, "some message")
        errors[:id]?.should be_nil
      end
    end
  end

  describe "#each" do
    it do
      errors = described_class.new(facebook_profile)
      errors.add(:uid)
      errors.add(:uid, :exclusion)
      errors.add(:id)
      attributes = [] of Symbol
      messages = [] of String
      errors.each do |attr, message|
        attributes << attr
        messages << message
      end
      messages.should eq(["is invalid", "is reserved", "is invalid"])
      attributes.should eq(%i(uid uid id))
    end
  end

  describe "#size" do
    it do
      errors = described_class.new(facebook_profile)
      errors.add(:uid)
      errors.add(:uid, :exclusion)
      errors.add(:id)
      errors.size.should eq(3)
    end
  end

  describe "#values" do
    it do
      errors = described_class.new(facebook_profile)
      errors.add(:uid)
      errors.add(:uid, :exclusion)
      errors.add(:id)
      errors.values.should eq(["is invalid", "is reserved", "is invalid"])
    end
  end

  describe "#keys" do
    it do
      errors = described_class.new(facebook_profile)
      errors.add(:uid)
      errors.add(:uid, :exclusion)
      errors.add(:id)
      errors.keys.should eq(%i(uid id))
    end
  end

  describe "#empty?" do
    it do
      errors = described_class.new(facebook_profile)
      errors.add(:uid)
      errors.empty?.should be_false
    end

    it do
      errors = described_class.new(facebook_profile)
      errors.empty?.should be_true
    end
  end

  describe "#any?" do
    it do
      errors = described_class.new(facebook_profile)
      errors.add(:uid)
      errors.empty?.should be_false
    end

    it do
      errors = described_class.new(facebook_profile)
      errors.empty?.should be_true
    end
  end

  describe "#blank?" do
    pending "add" do
    end
  end

  describe "#add" do
    context "with text message" do
      it do
        errors = described_class.new(facebook_profile)
        errors.add(:uid, "some text")
        errors[:uid][0].should eq("some text")
      end
    end

    context "with symbol message" do
      it do
        errors = described_class.new(facebook_profile)
        errors.add(:uid)
        errors[:uid][0].should eq("is invalid")
      end

      it do
        errors = described_class.new(facebook_profile)
        errors.add(:uid, :exclusion)
        errors[:uid][0].should eq("is reserved")
      end

      context "with custom class" do
        it do
          errors = described_class.new(Spec::TestClassForError.new)
          errors.add(:uid)
          errors[:uid][0].should eq("is invalid")
        end
      end
    end

    context "with count" do
      it do
        errors = described_class.new(facebook_profile)
        errors.add(:uid, :too_long, 2)
        errors[:uid][0].should eq("is too long (maximum is 2 characters)")
      end
    end

    context "with options" do
      it do
        errors = described_class.new(facebook_profile)
        errors.add(:uid, :equal_to, options: {:value => 3})
        errors[:uid][0].should eq("must be equal to 3")
      end
    end
  end

  describe "#full_messages" do
    it do
      errors = described_class.new(facebook_profile)
      errors.add(:uid)
      errors.add(:uid, :exclusion)
      errors.add(:id)
      errors.full_messages.should eq(["Uid is invalid", "Uid is reserved", "Id is invalid"])
    end

    context "with custom class" do
      it do
        errors = described_class.new(Spec::TestClassForError.new)
        errors.add(:uid)
        errors.add(:uid, :exclusion)
        errors.add(:id)
        errors.full_messages.should eq(["Uid is invalid", "Uid is reserved", "Id is invalid"])
      end

      pending "with custom context"
    end
  end

  describe "#to_a" do
    pending "add" do
    end
  end

  describe "#full_messages_for" do
    pending "add" do
    end
  end

  describe "#full_message" do
    pending "add" do
    end
  end

  describe "#generate_message" do
    errors = described_class.new(facebook_profile)

    context "without count" do
      empty_options = {count: nil, options: {} of String => String}

      it { errors.generate_message(:uid, :child_error, **empty_options).should eq("uid child error") }
      it { errors.generate_message(:id, :child_error, **empty_options).should eq("model child error") }
      it { errors.generate_message(:id, :parent_error, **empty_options).should eq("id parent error") }
      it { errors.generate_message(:uid, :parent_error, **empty_options).should eq("model parent error") }
      it { errors.generate_message(:name, :global_error, **empty_options).should eq("name global error") }
      it { errors.generate_message(:id, :global_error, **empty_options).should eq("global error") }
      it { errors.generate_message(:id, :unknown_message, **empty_options).should eq("unknown message") }
    end

    context "with count" do
      it { errors.generate_message(:uid, :too_long, 1, {} of String => String).should eq("is too long (maximum is 1 character)") }
      it { errors.generate_message(:uid, :too_long, 2, {} of String => String).should eq("is too long (maximum is 2 characters)") }
    end

    context "with options" do
      it { errors.generate_message(:uid, :equal_to, nil, {:value => "asd"}).should eq("must be equal to asd") }
    end
  end

  describe "#inspect" do
    it do
      errors = described_class.new(facebook_profile)
      errors.add(:uid)
      errors.inspect.should match(/#<Jennifer::Model::Errors:0x[\w\d]{12} @messages={:uid => \["is invalid"\]}>/)
    end
  end

  describe ".new" do
    it do
      described_class.new(Factory.build_contact)
      described_class.new(Factory.build_address)
    end
  end
end
