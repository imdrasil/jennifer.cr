require "../spec_helper"

macro validation_class_generator(klass, name, **options)
  class {{klass}} < AbstractContactModel
    validates_numericality {{name}}, {{**options}}
  end
end

validation_class_generator(GTContact, :age, greater_than: 20)
validation_class_generator(GTEContact, :age, greater_than_or_equal_to: 20)
validation_class_generator(EContact, :age, equal_to: 20)
validation_class_generator(LTContact, :age, less_than: 20)
validation_class_generator(LTEContact, :age, less_than_or_equal_to: 20)
validation_class_generator(OTContact, :age, other_than: 20)
validation_class_generator(OddContact, :age, odd: true)
validation_class_generator(EvenContact, :age, even: true)
validation_class_generator(SeveralValidationsContact, :age, greater_than: 20, less_than_or_equal_to: 30)

class GTNContact < Jennifer::Model::Base
  table_name "contacts"

  mapping({
    id: Primary32,
    age: Int32?
  }, false)

  validates_numericality :age, greater_than: 20, allow_blank: true
end

describe Jennifer::Model::Validation do
  describe "%validates_with" do
    it "accepts accord class validators" do
      p = Factory.build_passport(enn: "abc")
      p.should_not be_valid
      p.enn = "bca"
      p.should be_valid
      p.save
      p.new_record?.should be_false
    end
  end

  describe "%validates_with_method" do
    it "pass valid" do
      a = Factory.build_contact(description: "1234567890")
      a.should be_valid
    end

    it "doesn't pass invalid" do
      a = Factory.build_contact(description: "12345678901")
      a.should_not be_valid
    end
  end

  describe "%validates_inclucions" do
    it "pass valid" do
      a = Factory.build_contact(age: 75)
      a.should be_valid
    end

    it "doesn't pass invalid" do
      a = Factory.build_contact(age: 76)
      a.should validate(:age).with("is not included in the list")
    end

    context "allows blank" do
      pending "doesn't add error message" do
      end

      pending "validates if presence" do
      end
    end
  end

  describe "%validates_exclusion" do
    it "pass valid" do
      c = Factory.build_country(name: "Costa")
      c.should be_valid
    end

    it "doesn't pass invalid" do
      c = Factory.build_country(name: "asd")
      c.should validate(:name).with("is reserved")
    end

    context "allows blank" do
      pending "doesn't add error message" do
      end

      pending "validates if presence" do
      end
    end
  end

  describe "%validates_format" do
    it "pass valid names" do
      a = Factory.build_address(street: "Saint Moon st.")
      a.should be_valid
    end

    it "doesn't pass invalid names" do
      a = Factory.build_address(street: "Saint Moon walk")
      a.should validate(:street).with("is invalid")
    end
    
    context "allows blank" do
      pending "doesn't add error message" do
      end

      pending "validates if presence" do
      end
    end
  end

  describe "%validates_length" do
    context "minimum" do
      it "pass valid names" do
        a = Factory.build_contact(name: "a")
        a.should be_valid
      end

      it "doesn't pass invalid names" do
        a = Factory.build_contact(name: "")
        a.should validate(:name).with("is too short (minimum is 1 character)")
      end

      context "allows blank" do
        it "doesn't add error message" do
          c = ContactWithDependencies.new({:name => "asd", :description => nil})
          c.should be_valid
        end

        it "validates if presence" do
          c = ContactWithInValidation.new({:name => "1"})
          c.should validate(:name).with("is too short (minimum is 2 characters)")
        end
      end
    end

    context "maximum" do
      context "doesn't allow blank" do
        it "adds error message if size is grater" do
          c = Factory.build_contact(name: "1234567890123456")
          c.should validate(:name).with("is too long (maximum is 15 characters)")
        end

        it "doesn't add error if size is less" do
          c = Factory.build_contact(name: "123456789012345")
          c.validate!
          c.errors[:name].empty?.should be_true
        end
      end

      context "allows blank" do
        pending "doesn't add error message" do
        end

        pending "validates if presence" do
        end
      end
    end

    context "in" do
      context "doesn't allow blank" do
        it "adds error message" do
          c = ContactWithInValidation.new({:name => nil})
          c.should validate(:name).with("can't be blank")
        end

        context "with present value" do
          it "validates too long" do
            c = ContactWithInValidation.new({:name => "12345678901"})
            c.should validate(:name).with("is too long (maximum is 10 characters)")
          end

          it "validates too short" do
            c = ContactWithInValidation.new({:name => "1"})
            c.should validate(:name).with("is too short (minimum is 2 characters)")
          end

          it "pass validation if satisfies" do
            c = ContactWithInValidation.new({:name => "12"})
            c.should be_valid
          end
        end
      end
    end

    context "is" do
      it "adds error if invalid" do
        p = Factory.create_facebook_profile(login: "asd", uid: "12")
        p.should validate(:uid).with("is the wrong length (should be 4 characters)")
      end

      it "does nothing if valid" do
        p = Factory.create_facebook_profile(login: "asd", uid: "1234")
        p.should be_valid
      end
    end
  end

  describe "%validates_uniqueness" do
    it "pass valid" do
      p = Factory.build_country(name: "123asd")
      p.should be_valid
    end

    it "doesn't pass invalid" do
      Factory.create_country(name: "123asd")
      p = Factory.build_country(name: "123asd")
      p.should validate(:name).with("has already been taken")
    end
  end

  describe "%validates_presence_of" do
    context "when field is not nil" do
      it "pass validation" do
        c = Country.build({:name => "New country"})
        c.should be_valid
      end
    end

    context "when field is nil" do
      it "doesn't pass validation" do
        c = Country.build({} of String => String)
        c.should validate(:name).with("can't be blank")
      end
    end
  end

  describe "%validates_numericality" do
    context "with allowed nil value" do
      it "passes validation if value is nil" do
        c = GTNContact.build({ :age => nil })
        c.should be_valid
      end

      it "process validation if value is not nil" do
        c = GTNContact.build({ :age => 20 })
        c.should_not be_valid
      end
    end

    context "with greater_than option" do
      it "adds error message if it breaks a condition" do
        c = GTContact.build(age: 20)
        c.should validate(:age).with("must be greater than 20")
      end

      it "pass validation if an attribute satisfies condition" do
        c = GTContact.build(age: 21)
        c.should be_valid
      end
    end

    context "with greater_than_or_equal_to option" do
      it "adds error message if it breaks a condition" do
        c = GTEContact.build(age: 19)
        c.should validate(:age).with("must be greater than or equal to 20")
      end

      it "pass validation if an attribute satisfies condition" do
        c = GTEContact.build(age: 20)
        c.should be_valid
      end
    end

    context "with equal_to option" do
      it "adds error message if it breaks a condition" do
        c = EContact.build(age: 19)
        c.should validate(:age).with("must be equal to 20")
      end

      it "pass validation if an attribute satisfies condition" do
        c = EContact.build(age: 20)
        c.should be_valid
      end
    end

    context "with less_than option" do
      it "adds error message if it breaks a condition" do
        c = LTContact.build(age: 20)
        c.should validate(:age).with("must be less than 20")
      end

      it "pass validation if an attribute satisfies condition" do
        c = LTContact.build(age: 19)
        c.should be_valid
      end
    end

    context "with less_than_or_equal_to option" do
      it "adds error message if it breaks a condition" do
        c = LTEContact.build(age: 21)
        c.should validate(:age).with("must be less than or equal to 20")
      end

      it "pass validation if an attribute satisfies condition" do
        c = LTEContact.build(age: 20)
        c.should be_valid
      end
    end

    context "with other_than option" do
      it "adds error message if it breaks a condition" do
        c = OTContact.build(age: 20)
        c.should validate(:age).with("must be other than 20")
      end

      it "pass validation if an attribute satisfies condition" do
        c = OTContact.build(age: 21)
        c.should be_valid
      end
    end

    context "with odd option" do
      it "adds error message if it breaks a condition" do
        c = OddContact.build(age: 20)
        c.should validate(:age).with("must be odd")
      end

      it "pass validation if an attribute satisfies condition" do
        c = OddContact.build(age: 21)
        c.should be_valid
      end
    end

    context "with even option" do
      it "adds error message if it breaks a condition" do
        c = EvenContact.build(age: 21)
        c.should validate(:age).with("must be even")
      end

      it "pass validation if an attribute satisfies condition" do
        c = EvenContact.build(age: 20)
        c.should be_valid
      end
    end

    context "with several specified validations" do
      it "adds error message if it breaks any condition" do
        c = SeveralValidationsContact.build(age: 20)
        c.should validate(:age).with("must be greater than 20")
        c.age = 31
        c.should validate(:age).with("must be less than or equal to 30")
      end

      it "pass validation if an attribute satisfies all conditions" do
        c = SeveralValidationsContact.build(age: 21)
        c.should be_valid
      end
    end
  end
end
