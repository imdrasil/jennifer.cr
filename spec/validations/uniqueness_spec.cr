require "../spec_helper"

describe Jennifer::Validations::Uniqueness do
  # ameba:disable Lint/UselessAssign
  described_class = Jennifer::Validations::Uniqueness

  describe "#validate" do
    it do
      Factory.create_contact(description: "test")
      validated_by_record(:description, "test", {query: Contact.where { _description == "test" }}).should has_error_message(:description, "has already been taken")
    end

    it do
      validated_by_record(:description, nil, {query: Contact.where { _description == "test" }}).should_not has_error_message(:description)
    end

    it { validated_by_record(:description, "John", {query: Contact.where { _description == "test" }}).should_not has_error_message(:description) }

    describe "message" do
      it do
        Factory.create_contact(description: "test")
        proc = ->(record : Jennifer::Model::Translation, field : String) do
          "#{record.as(Contact).attribute(field).inspect} #{field} invalid"
        end
        validated_by_record(:description, "test", {message: proc, query: Contact.where { _description == "test" }})
          .should has_error_message(:description, "nil description invalid")
      end
    end
  end

  pending "test allow_blank"
  pending "test query"
end
