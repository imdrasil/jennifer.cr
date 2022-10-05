require "../spec_helper"

describe Jennifer::Validations::Acceptance do
  # ameba:disable Lint/UselessAssign
  described_class = Jennifer::Validations::Acceptance

  describe "#validate" do
    it { validated_by_record(:name, "yes", {accept: %w[yes]}).should_not has_error_message(:name) }
    it { validated_by_record(:name, nil, {accept: %w[yes]}).should_not has_error_message(:name) }
    it { validated_by_record(:name, "no", {accept: %w[yes]}).should has_error_message(:name, "must be accepted") }

    describe "message" do
      it do
        proc = ->(record : Jennifer::Model::Translation, field : String) do
          "#{record.as(Contact).attribute(field)} #{field} invalid"
        end
        validated_by_record(:name, "no", {message: proc, accept: %w[yes]})
          .should has_error_message(:name, "Deepthi name invalid")
      end
    end
  end
end
