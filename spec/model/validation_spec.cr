require "../spec_helper"

describe Jennifer::Model::Validation do
  describe "validates_with" do
    it "accepts accord class validators" do
      p = passport_build(enn: "abc")
      p.validate!
      p.valid?.should be_false
      p.enn = "bca"
      p.validate!
      p.valid?.should be_true
      p.save
      p.new_record?.should be_false
    end
  end

  describe "validates_with_method" do
    it "pass valid" do
      a = contact_build(description: "1234567890")
      a.validate!
      a.valid?.should be_true
    end

    it "doesn't pass invalid" do
      a = contact_build(description: "12345678901")
      a.validate!
      a.valid?.should be_false
    end
  end

  describe "validates_inclucions" do
    it "pass valid" do
      a = contact_build(age: 75)
      a.validate!
      a.valid?.should be_true
    end

    it "doesn't pass invalid" do
      a = contact_build(age: 76)
      a.validate!
      a.valid?.should be_false
    end
  end

  describe "validates_exclusion" do
    it "pass valid" do
      c = country_build(name: "Costa")
      c.validate!
      c.valid?.should be_true
    end

    it "doesn't pass invalid" do
      c = country_build(name: "asd")
      c.validate!
      c.valid?.should be_false
    end
  end

  describe "validates_format" do
    it "pass valid names" do
      a = address_build(street: "Saint Moon st.")
      a.validate!
      a.valid?.should be_true
    end

    it "doesn't pass invalid names" do
      a = address_build(street: "Saint Moon walk")
      a.validate!
      a.valid?.should be_false
    end
  end

  describe "validates_length" do
    context "minimum" do
      it "pass valid names" do
        a = contact_build(name: "a")
        a.validate!
        a.valid?.should be_true
      end

      it "doesn't pass invalid names" do
        a = contact_build(name: "")
        a.validate!
        a.valid?.should be_false
      end
    end

    context "maximum" do
      it "pass valid names" do
        a = contact_build(name: "123456789012345")
        a.validate!
        a.valid?.should be_true
      end

      it "doesn't pass invalid names" do
        a = contact_build(name: "1234567890123456")
        a.validate!
        a.valid?.should be_false
      end
    end

    pending "in" do
    end

    pending "is" do
    end
  end

  describe "validates_uniqueness" do
    it "pass valid" do
      p = country_build(name: "123asd")
      p.validate!
      p.valid?.should be_true
    end

    it "doesn't pass invalid" do
      country_create(name: "123asd")
      p = country_build(name: "123asd")
      p.validate!
      p.valid?.should be_false
    end
  end
end
