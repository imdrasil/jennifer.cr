require "../spec_helper"

describe Jennifer::Validations::Inclusion do
  # ameba:disable Lint/UselessAssign
  described_class = Jennifer::Validations::Inclusion
  message = "is not included in the list"

  describe "#validate" do
    describe "String" do
      it { validated_by_record(:name, "John", {collection: ["Sam"]}).should has_error_message(:name, message) }
      it { validated_by_record(:name, "Sam", {collection: ["Sam"]}).should_not has_error_message(:name) }
      it { validated_by_record(:name, nil, {collection: ["Sam"]}).should_not has_error_message(:name) }
    end

    describe "Float32" do
      it { validated_by_record(:name, 2.5, {collection: [1.2]}).should has_error_message(:name, message) }
      it { validated_by_record(:name, 1.2, {collection: [1.2]}).should_not has_error_message(:name) }
      it { validated_by_record(:name, nil, {collection: [1.2]}).should_not has_error_message(:name) }
    end

    describe "Int32" do
      it { validated_by_record(:name, 2, {collection: [1]}).should has_error_message(:name, message) }
      it { validated_by_record(:name, 1, {collection: [1]}).should_not has_error_message(:name) }
      it { validated_by_record(:name, nil, {collection: [1]}).should_not has_error_message(:name) }
    end

    describe "message" do
      it do
        proc = ->(record : Jennifer::Model::Translation, field : String) do
          "#{record.as(Contact).attribute(field)} #{field} invalid"
        end
        validated_by_record(:name, 2, {collection: [1], message: proc})
          .should has_error_message(:name, "Deepthi name invalid")
      end
    end
  end

  pending "test allow_blank"
end
