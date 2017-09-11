require "../spec_helper"

describe Jennifer::Model::Validation do
  describe "validates_with" do
    it "accepts accord class validators" do
      p = Factory.build_passport(enn: "abc")
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
      a = Factory.build_contact(description: "1234567890")
      a.validate!
      a.valid?.should be_true
    end

    it "doesn't pass invalid" do
      a = Factory.build_contact(description: "12345678901")
      a.validate!
      a.valid?.should be_false
    end
  end

  describe "validates_inclucions" do
    it "pass valid" do
      a = Factory.build_contact(age: 75)
      a.validate!
      a.valid?.should be_true
    end

    it "doesn't pass invalid" do
      a = Factory.build_contact(age: 76)
      a.validate!
      a.valid?.should be_false
    end
  end

  describe "validates_exclusion" do
    it "pass valid" do
      c = Factory.build_country(name: "Costa")
      c.validate!
      c.valid?.should be_true
    end

    it "doesn't pass invalid" do
      c = Factory.build_country(name: "asd")
      c.validate!
      c.valid?.should be_false
    end
  end

  describe "validates_format" do
    it "pass valid names" do
      a = Factory.build_address(street: "Saint Moon st.")
      a.validate!
      a.valid?.should be_true
    end

    it "doesn't pass invalid names" do
      a = Factory.build_address(street: "Saint Moon walk")
      a.validate!
      a.valid?.should be_false
    end
  end

  describe "validates_length" do
    context "minimum" do
      it "pass valid names" do
        a = Factory.build_contact(name: "a")
        a.validate!
        a.valid?.should be_true
      end

      it "doesn't pass invalid names" do
        a = Factory.build_contact(name: "")
        a.validate!
        a.valid?.should be_false
      end
    end

    context "maximum" do
      it "pass valid names" do
        a = Factory.build_contact(name: "123456789012345")
        a.validate!
        a.valid?.should be_true
      end

      it "doesn't pass invalid names" do
        a = Factory.build_contact(name: "1234567890123456")
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
      p = Factory.build_country(name: "123asd")
      p.validate!
      p.valid?.should be_true
    end

    it "doesn't pass invalid" do
      Factory.create_country(name: "123asd")
      p = Factory.build_country(name: "123asd")
      p.validate!
      p.valid?.should be_false
    end
  end
end
