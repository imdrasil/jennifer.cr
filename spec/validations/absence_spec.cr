require "../spec_helper"

describe Jennifer::Validations::Absence do
  # ameba:disable Lint/UselessAssign
  described_class = Jennifer::Validations::Absence

  describe "#validate" do
    it { validated_by_record(:description, "John").should has_error_message(:description, "must be blank") }
    it { validated_by_record(:description, nil).should_not has_error_message(:description) }

    describe "message" do
      it do
        proc = ->(record : Jennifer::Model::Translation, field : String) { "#{record.as(Address).attribute(field).inspect} #{field} invalid" }
        validated_by_record(:contact_id, 1, {message: proc, record: Factory.build_address})
          .should has_error_message(:contact_id, "nil contact_id invalid")
      end
    end
  end

  pending "test allow_blank"
end
