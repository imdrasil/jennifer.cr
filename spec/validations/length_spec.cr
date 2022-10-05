require "../spec_helper"

describe Jennifer::Validations::Length do
  # ameba:disable Lint/UselessAssign
  described_class = Jennifer::Validations::Length

  describe "#validate" do
    describe "in" do
      describe "String" do
        it { validated_by_record(:name, "Joh", {in: 2..3}).should_not has_error_message(:name) }
        it { validated_by_record(:name, "Jo", {in: 2..3}).should_not has_error_message(:name) }

        it do
          validated_by_record(:name, "Sam", {in: 2...3})
            .should has_error_message(:name, "is too long (maximum is 2 characters)")
        end

        it do
          validated_by_record(:name, "S", {in: 2...3})
            .should has_error_message(:name, "is too short (minimum is 2 characters)")
        end
      end

      describe "Array" do
        it { validated_by_record(:name, [1, 2, 3], {in: 2..3}).should_not has_error_message(:name) }
        it { validated_by_record(:name, [1, 2], {in: 2..3}).should_not has_error_message(:name) }

        it do
          validated_by_record(:name, [1, 2, 3], {in: 2...3})
            .should has_error_message(:name, "is too long (maximum is 2 characters)")
        end

        it do
          validated_by_record(:name, [1], {in: 2...3})
            .should has_error_message(:name, "is too short (minimum is 2 characters)")
        end
      end

      it { validated_by_record(:name, nil, {in: 2..3}).should_not has_error_message(:name) }
    end

    describe "is" do
      describe "String" do
        it { validated_by_record(:name, "Joh", {is: 3}).should_not has_error_message(:name) }

        it do
          validated_by_record(:name, "Jo", {is: 3})
            .should has_error_message(:name, "is the wrong length (should be 3 characters)")
        end
      end

      describe "Array" do
        it { validated_by_record(:name, [1, 2, 3], {is: 3}).should_not has_error_message(:name) }

        it do
          validated_by_record(:name, [1, 2], {is: 3})
            .should has_error_message(:name, "is the wrong length (should be 3 characters)")
        end
      end

      it { validated_by_record(:name, nil, {is: 3}).should_not has_error_message(:name) }
    end

    describe "minimum" do
      describe "String" do
        it { validated_by_record(:name, "Joh", {minimum: 3}).should_not has_error_message(:name) }

        it do
          validated_by_record(:name, "Jo", {minimum: 3})
            .should has_error_message(:name, "is too short (minimum is 3 characters)")
        end
      end

      describe "Array" do
        it { validated_by_record(:name, [1, 2, 3], {minimum: 3}).should_not has_error_message(:name) }

        it do
          validated_by_record(:name, [1, 2], {minimum: 3})
            .should has_error_message(:name, "is too short (minimum is 3 characters)")
        end
      end

      it { validated_by_record(:name, nil, {minimum: 3}).should_not has_error_message(:name) }
    end

    describe "maximum" do
      describe "String" do
        it { validated_by_record(:name, "Joh", {maximum: 3}).should_not has_error_message(:name) }

        it do
          validated_by_record(:name, "John", {maximum: 3})
            .should has_error_message(:name, "is too long (maximum is 3 characters)")
        end
      end

      describe "Array" do
        it { validated_by_record(:name, [1, 2, 3], {maximum: 3}).should_not has_error_message(:name) }

        it do
          validated_by_record(:name, [1, 2, 3, 4], {maximum: 3})
            .should has_error_message(:name, "is too long (maximum is 3 characters)")
        end
      end

      it { validated_by_record(:name, nil, {maximum: 3}).should_not has_error_message(:name) }
    end

    describe "message" do
      it do
        proc = ->(record : Jennifer::Model::Translation, field : String) do
          "#{record.as(Contact).attribute(field)} #{field} invalid"
        end
        validated_by_record(:name, [1, 2, 3, 4], {maximum: 3, message: proc})
          .should has_error_message(:name, "Deepthi name invalid")
      end
    end
  end

  pending "test allow_blank"
end
