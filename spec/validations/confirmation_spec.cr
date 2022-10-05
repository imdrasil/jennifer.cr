require "../spec_helper"

describe Jennifer::Validations::Confirmation do
  # ameba:disable Lint/UselessAssign
  described_class = Jennifer::Validations::Confirmation

  describe "#validate" do
    it { validated_by_record(:name, "John", {confirmation: "Joh", case_sensitive: true}).should has_error_message(:name, "doesn't match tName") }
    it { validated_by_record(:name, nil, {case_sensitive: true}).should_not has_error_message(:name) }

    it do
      validated_by_record(:name, "John", {confirmation: "John", case_sensitive: true}).should_not has_error_message(:name)
    end

    describe "message" do
      it do
        proc = ->(record : Jennifer::Model::Translation, field : String) do
          "#{record.as(Contact).attribute(field)} #{field} invalid"
        end
        validated_by_record(:name, "John", {message: proc, confirmation: "Joh", case_sensitive: true})
          .should has_error_message(:name, "Deepthi name invalid")
      end
    end
  end

  pending "test allow_blank"
  pending "test case_sensitive"
end
