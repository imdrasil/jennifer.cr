require "../spec_helper"

describe Jennifer::Validations::Presence do
  # ameba:disable Lint/UselessAssign
  described_class = Jennifer::Validations::Presence

  describe "#validate" do
    it { validated_by_record(:description, nil).should has_error_message(:description, "can't be blank") }
    it { validated_by_record(:description, "John").should_not has_error_message(:description) }

    describe "message" do
      it do
        proc = ->(record : Jennifer::Model::Translation, field : String) { "#{record.as(Address).attribute(field).inspect} #{field} invalid" }
        validated_by_record(:contact_id, nil, {message: proc, record: Factory.build_address})
          .should has_error_message(:contact_id, "nil contact_id invalid")
      end
    end
  end

  pending "test allow_blank"
end
