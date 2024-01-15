require "../spec_helper"

macro validation_class_generator(klass, name, **options)
  class {{klass}} < AbstractContactModel
    {{yield}}
    validates_numericality {{name}}, {{options.double_splat}}
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

postgres_only do
  class NumericGTContact < Jennifer::Model::Base
    table_name "contacts"

    mapping({
      id:       Primary64,
      ballance: {type: BigDecimal, converter: Jennifer::Model::BigDecimalConverter(PG::Numeric), scale: 2},
    }, false)

    validates_numericality :ballance, greater_than: 20
  end
end

class GTNContact < Jennifer::Model::Base
  table_name "contacts"

  mapping({
    id:          Primary64,
    age:         Int32?,
    validatable: {type: Bool, default: true, virtual: true},
  }, false)

  validates_numericality :age, greater_than: 20, allow_blank: true, if: :validatable
  validates_numericality :age, greater_than: 15, allow_blank: true, if: !validatable
end

class AcceptanceContact < ApplicationRecord
  mapping({
    id:               Primary64,
    name:             String,
    terms_of_service: {type: Bool, default: false, virtual: true},
    eula:             {type: String?, virtual: true},
  }, false)

  validates_acceptance :terms_of_service
  validates_acceptance :eula, accept: %w(true accept yes)
end

class ConfirmationContact < ApplicationRecord
  mapping({
    id:                                 Primary64,
    name:                               String?,
    case_insensitive_name:              String?,
    name_confirmation:                  {type: String?, virtual: true},
    case_insensitive_name_confirmation: {type: String?, virtual: true},
  }, false)

  validates_confirmation :name
  validates_confirmation :case_insensitive_name, case_sensitive: false
end

class PresenceContact < ApplicationRecord
  mapping({
    id:          Primary64,
    name:        String?,
    address:     String?,
    confirmable: {type: Bool, virtual: true, default: true},
  })

  validates_presence :name, if: :confirmable?
  validates_absence :address

  # NOTE: method is defined to check it's accessability in validation
  private def confirmable?
    confirmable
  end
end

class ValidatorWithOptions < Jennifer::Validations::Validator
  def validate(record, **opts)
    field = opts[:field]

    if record.attribute(field) == "invalid"
      record.errors.add(field, opts[:message]? || "blank")
    end
  end
end

class CustomValidatorModel < ApplicationRecord
  mapping({
    id:   Primary64,
    name: String,
  })

  validates_with ValidatorWithOptions, field: :name, message: "Custom Message"
end

class SymbolMessageValidationModel < ApplicationRecord
  mapping({
    id:   Primary64,
    name: String,
  })

  validates_format :name, /qwe/, message: :present
end

class StringMessageValidationModel < ApplicationRecord
  mapping({
    id:   Primary64,
    name: String,
  })

  validates_length :name, is: 3, message: "String message"
end

class ProcMessageValidationModel < ApplicationRecord
  mapping({
    id:   Primary64,
    name: String,
  })

  validates_length :name, is: 3, message: ->(record : Jennifer::Model::Translation, _field : String) do
    record.as(ProcMessageValidationModel).name
  end
end

describe Jennifer::Model::Validation do
  describe "if option" do
    context "with negative response" do
      it "doesn't invoke related validation" do
        c = PresenceContact.new
        c.confirmable = false
        c.should be_valid
      end
    end

    context "with expression" do
      it do
        c = GTNContact.new({:age => 16})
        c.validatable = false
        c.should be_valid
        c.age = 14
        c.should_not be_valid
      end
    end
  end

  describe "message option" do
    it "uses string value as a complete message" do
      record = StringMessageValidationModel.new({name: "1234"})
      record.should validate(:name).with("String message")
    end

    it "uses symbol message as a key for message translation lookup" do
      record = SymbolMessageValidationModel.new({name: "1234"})
      record.should validate(:name).with("must be blank")
    end

    it "uses proc message to generate message dynamically" do
      record = ProcMessageValidationModel.new({name: "1234"})
      record.should validate(:name).with("1234")
    end
  end

  describe "%validates_with" do
    it "accepts class validators" do
      p = Factory.build_passport(enn: "abc")
      p.should_not be_valid
      p.enn = "bca"
      p.should be_valid
      p.save
      p.new_record?.should be_false
    end

    context "with extra options" do
      it do
        subject = CustomValidatorModel.new({name: "valid"})
        subject.should be_valid
      end

      it do
        subject = CustomValidatorModel.new({name: "invalid"})
        subject.should validate(:name).with("Custom Message")
      end
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

  describe "%validates_inclusions" do
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
    it { Factory.build_country(name: "123asd").should be_valid }
    it { Factory.create_country(name: "123asd").should be_valid }

    it do
      Factory.create_country(name: "123asd")
      p = Factory.build_country(name: "123asd")
      p.should validate(:name).with("has already been taken")
    end

    pending "allows blank"

    it "should do nothing if the combination of values is unique" do
      c = Factory.create_contact(
        name: "Tess Tee",
        age: 22,
        gender: "female"
      )

      p1 = Factory.create_passport(enn: "xyz0", contact_id: c.id)
      p1.should be_valid

      p2 = Factory.build_passport(enn: "E928", contact_id: c.id)
      p2.should be_valid
    end

    it "should not allow combinations of values that already exist" do
      c = Factory.create_contact(
        name: "Test R. Numberone",
        age: 43,
        gender: "male"
      )

      p1 = Factory.create_passport(enn: "z0134", contact_id: c.id)
      p1.should be_valid

      p2 = Factory.build_passport(enn: "z0134", contact_id: c.id)
      p2.should_not be_valid
      p2.should validate(:enn_contact_id).with("has already been taken")
    end
  end

  describe "%validates_presence" do
    context "when field is not nil" do
      it "pass validation" do
        c = PresenceContact.new({:name => "New country"})
        c.should be_valid
      end
    end

    context "when field is nil" do
      it "doesn't pass validation" do
        c = PresenceContact.new
        c.should validate(:name).with("can't be blank")
      end
    end
  end

  describe "%validates_absence" do
    context "when field is not nil" do
      it "pass validation" do
        c = PresenceContact.new({:name => "New country"})
        c.should be_valid
      end
    end

    context "when field is nil" do
      it "doesn't pass validation" do
        c = PresenceContact.new({:address => "asd"})
        c.should validate(:address).with("must be blank")
      end
    end
  end

  describe "%validates_numericality" do
    context "with allowed nil value" do
      it "passes validation if value is nil" do
        c = GTNContact.new({:age => nil})
        c.should be_valid
      end

      it "process validation if value is not nil" do
        c = GTNContact.new({:age => 20})
        c.should_not be_valid
      end
    end

    context "with greater_than option" do
      it "adds error message if it breaks a condition" do
        c = GTContact.new({age: 20})
        c.should validate(:age).with("must be greater than 20")
      end

      it "pass validation if an attribute satisfies condition" do
        c = GTContact.new({age: 21})
        c.should be_valid
      end

      postgres_only do
        it "works with BigDecimal" do
          c = NumericGTContact.new({ballance: 19.0})
          c.should validate(:ballance).with("must be greater than 20")
        end
      end
    end

    context "with greater_than_or_equal_to option" do
      it "adds error message if it breaks a condition" do
        c = GTEContact.new({age: 19})
        c.should validate(:age).with("must be greater than or equal to 20")
      end

      it "pass validation if an attribute satisfies condition" do
        c = GTEContact.new({age: 20})
        c.should be_valid
      end
    end

    context "with equal_to option" do
      it "adds error message if it breaks a condition" do
        c = EContact.new({age: 19})
        c.should validate(:age).with("must be equal to 20")
      end

      it "pass validation if an attribute satisfies condition" do
        c = EContact.new({age: 20})
        c.should be_valid
      end
    end

    context "with less_than option" do
      it "adds error message if it breaks a condition" do
        c = LTContact.new({age: 20})
        c.should validate(:age).with("must be less than 20")
      end

      it "pass validation if an attribute satisfies condition" do
        c = LTContact.new({age: 19})
        c.should be_valid
      end
    end

    context "with less_than_or_equal_to option" do
      it "adds error message if it breaks a condition" do
        c = LTEContact.new({age: 21})
        c.should validate(:age).with("must be less than or equal to 20")
      end

      it "pass validation if an attribute satisfies condition" do
        c = LTEContact.new({age: 20})
        c.should be_valid
      end
    end

    context "with other_than option" do
      it "adds error message if it breaks a condition" do
        c = OTContact.new({age: 20})
        c.should validate(:age).with("must be other than 20")
      end

      it "pass validation if an attribute satisfies condition" do
        c = OTContact.new({age: 21})
        c.should be_valid
      end
    end

    context "with odd option" do
      it "adds error message if it breaks a condition" do
        c = OddContact.new({age: 20})
        c.should validate(:age).with("must be odd")
      end

      it "pass validation if an attribute satisfies condition" do
        c = OddContact.new({age: 21})
        c.should be_valid
      end
    end

    context "with even option" do
      it "adds error message if it breaks a condition" do
        c = EvenContact.new({age: 21})
        c.should validate(:age).with("must be even")
      end

      it "pass validation if an attribute satisfies condition" do
        c = EvenContact.new({age: 20})
        c.should be_valid
      end
    end

    context "with several specified validations" do
      it "adds error message if it breaks any condition" do
        c = SeveralValidationsContact.new({age: 20})
        c.should validate(:age).with("must be greater than 20")
        c.age = 31
        c.should validate(:age).with("must be less than or equal to 30")
      end

      it "pass validation if an attribute satisfies all conditions" do
        c = SeveralValidationsContact.new({age: 21})
        c.should be_valid
      end
    end

    context "with if condition" do
      it "doesn't invoke related validation if condition is negative" do
        c = GTNContact.new({:age => 16})
        c.validatable = false
        c.should be_valid
      end
    end
  end

  describe "%validates_acceptance" do
    it "pass validation" do
      c = AcceptanceContact.new({:name => "New country", :terms_of_service => true, :eula => "yes"})
      c.should be_valid
    end

    it "adds error message if doesn't satisfies validation" do
      c = AcceptanceContact.new({:name => "New country", :eula => "no"})
      c.should validate(:terms_of_service).with("must be accepted")
      c.should validate(:eula).with("must be accepted")
    end
  end

  describe "%validates_confirmation" do
    context "with nil confirmations" do
      it "pass validation" do
        c = ConfirmationContact.new({:name => "name"})
        c.should be_valid
      end
    end

    it "pass validation" do
      c = ConfirmationContact.new({
        :name                               => "name",
        :case_insensitive_name              => "cin",
        :name_confirmation                  => "name",
        :case_insensitive_name_confirmation => "CIN",
      })
      c.should be_valid
    end

    it "adds error message if doesn't satisfies validation" do
      c = ConfirmationContact.new({
        :name                               => "name",
        :case_insensitive_name              => "cin",
        :name_confirmation                  => "Name",
        :case_insensitive_name_confirmation => "NIC",
      })
      c.should validate(:name).with("doesn't match Name")
      c.should validate(:case_insensitive_name).with("doesn't match Case insensitive name")
    end
  end
end
