require "../spec_helper"

describe Jennifer::Validations::Format do
  # ameba:disable Lint/UselessAssign
  described_class = Jennifer::Validations::Format

  describe "#validate" do
    it { validated_by_record(:name, "John", {format: /jon/}).should has_error_message(:name, "is invalid") }
    it { validated_by_record(:name, nil, {format: /jon/}).should_not has_error_message(:name) }

    it { validated_by_record(:name, "John", {format: /John/}).should_not has_error_message(:name) }

    describe "message" do
      it do
        proc = ->(record : Jennifer::Model::Translation, field : String) do
          "#{record.as(Contact).attribute(field)} #{field} invalid"
        end
        validated_by_record(:name, "John", {message: proc, format: /jon/})
          .should has_error_message(:name, "Deepthi name invalid")
      end
    end
  end

  pending "test allow_blank"
  pending "test case_sensitive"
end
