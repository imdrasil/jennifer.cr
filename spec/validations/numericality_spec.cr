require "../spec_helper"

describe Jennifer::Validations::Numericality do
  # ameba:disable Lint/UselessAssign
  described_class = Jennifer::Validations::Numericality

  describe "#validate" do
    {% begin %}
    describe "greater_than" do
      {% definition = {greater_than: 12} %}

      describe "Int32" do
        it { validated_by_record(:age, 13, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 12, {{definition}}).should be_invalid }
      end

      describe "Int16" do
        it { validated_by_record(:age, 13i64, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 12i64, {{definition}}).should be_invalid }
      end

      describe "Float64" do
        it { validated_by_record(:age, 13.0, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 12.0, {{definition}}).should be_invalid }
      end

      describe "Float32" do
        it { validated_by_record(:age, 13.0f32, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 12.0f32, {{definition}}).should be_invalid }
      end

      describe "Nil" do
        it { validated_by_record(:age, nil, {{definition}}).should_not be_invalid }
      end
    end

    describe "greater_than_or_equal_to" do
      {% definition = {greater_than_or_equal_to: 12} %}

      describe "Int32" do
        it { validated_by_record(:age, 12, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 11, {{definition}}).should be_invalid }
      end

      describe "Int16" do
        it { validated_by_record(:age, 12i64, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 11i64, {{definition}}).should be_invalid }
      end

      describe "Float64" do
        it { validated_by_record(:age, 12.0, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 11.0, {{definition}}).should be_invalid }
      end

      describe "Float32" do
        it { validated_by_record(:age, 12.0f32, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 11.0f32, {{definition}}).should be_invalid }
      end

      describe "Nil" do
        it { validated_by_record(:age, nil, {{definition}}).should_not be_invalid }
      end
    end

    describe "equal_to" do
      {% definition = {equal_to: 12} %}

      describe "Int32" do
        it { validated_by_record(:age, 12, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 11, {{definition}}).should be_invalid }
        it { validated_by_record(:age, 13, {{definition}}).should be_invalid }
      end

      describe "Int16" do
        it { validated_by_record(:age, 12i64, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 11i64, {{definition}}).should be_invalid }
        it { validated_by_record(:age, 13i64, {{definition}}).should be_invalid }
      end

      describe "Float64" do
        it { validated_by_record(:age, 12.0, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 11.0, {{definition}}).should be_invalid }
        it { validated_by_record(:age, 13.0, {{definition}}).should be_invalid }
      end

      describe "Float32" do
        it { validated_by_record(:age, 12.0f32, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 11.0f32, {{definition}}).should be_invalid }
        it { validated_by_record(:age, 13.0f32, {{definition}}).should be_invalid }
      end

      describe "Nil" do
        it { validated_by_record(:age, nil, {{definition}}).should_not be_invalid }
      end
    end

    describe "other_than" do
      {% definition = {other_than: 12} %}

      describe "Int32" do
        it { validated_by_record(:age, 12, {{definition}}).should be_invalid }
        it { validated_by_record(:age, 11, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 13, {{definition}}).should_not be_invalid }
      end

      describe "Int16" do
        it { validated_by_record(:age, 12i64, {{definition}}).should be_invalid }
        it { validated_by_record(:age, 11i64, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 13i64, {{definition}}).should_not be_invalid }
      end

      describe "Float64" do
        it { validated_by_record(:age, 12.0, {{definition}}).should be_invalid }
        it { validated_by_record(:age, 11.0, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 13.0, {{definition}}).should_not be_invalid }
      end

      describe "Float32" do
        it { validated_by_record(:age, 12.0f32, {{definition}}).should be_invalid }
        it { validated_by_record(:age, 11.0f32, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 13.0f32, {{definition}}).should_not be_invalid }
      end

      describe "Nil" do
        it { validated_by_record(:age, nil, {{definition}}).should_not be_invalid }
      end
    end

    describe "less_than" do
      {% definition = {less_than: 12} %}

      describe "Int32" do
        it { validated_by_record(:age, 11, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 12, {{definition}}).should be_invalid }
      end

      describe "Int16" do
        it { validated_by_record(:age, 11i64, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 12i64, {{definition}}).should be_invalid }
      end

      describe "Float64" do
        it { validated_by_record(:age, 11.0, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 12.0, {{definition}}).should be_invalid }
      end

      describe "Float32" do
        it { validated_by_record(:age, 11.0f32, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 12.0f32, {{definition}}).should be_invalid }
      end

      describe "Nil" do
        it { validated_by_record(:age, nil, {{definition}}).should_not be_invalid }
      end
    end

    describe "less_than_or_equal_to" do
      {% definition = {less_than_or_equal_to: 12} %}

      describe "Int32" do
        it { validated_by_record(:age, 12, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 13, {{definition}}).should be_invalid }
      end

      describe "Int16" do
        it { validated_by_record(:age, 12i64, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 13i64, {{definition}}).should be_invalid }
      end

      describe "Float64" do
        it { validated_by_record(:age, 12.0, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 13.0, {{definition}}).should be_invalid }
      end

      describe "Float32" do
        it { validated_by_record(:age, 12.0f32, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 13.0f32, {{definition}}).should be_invalid }
      end

      describe "Nil" do
        it { validated_by_record(:age, nil, {{definition}}).should_not be_invalid }
      end
    end

    describe "odd" do
      {% definition = {odd: true} %}

      describe "Int32" do
        it { validated_by_record(:age, 13, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 14, {{definition}}).should be_invalid }
      end

      describe "Int16" do
        it { validated_by_record(:age, 13i64, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 14i64, {{definition}}).should be_invalid }
      end

      describe "Float64" do
        it { validated_by_record(:age, 13.0, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 14.0, {{definition}}).should be_invalid }
      end

      describe "Float32" do
        it { validated_by_record(:age, 13.0f32, {{definition}}).should_not be_invalid }
        it { validated_by_record(:age, 14.0f32, {{definition}}).should be_invalid }
      end

      describe "String" do
        it do
          expect_raises(ArgumentError) do
            validated_by_record(:age, "13", {{definition}}).should_not be_invalid
          end
        end
      end

      describe "Nil" do
        it { validated_by_record(:age, nil, {{definition}}).should_not be_invalid }
      end
    end

    describe "even" do
      describe "Int32" do
        it { validated_by_record(:age, 14, {even: true}).should_not be_invalid }
        it { validated_by_record(:age, 13, {even: true}).should be_invalid }
      end

      describe "Int16" do
        it { validated_by_record(:age, 14i64, {even: true}).should_not be_invalid }
        it { validated_by_record(:age, 13i64, {even: true}).should be_invalid }
      end

      describe "Float64" do
        it { validated_by_record(:age, 14.0, {even: true}).should_not be_invalid }
        it { validated_by_record(:age, 13.0, {even: true}).should be_invalid }
      end

      describe "Float32" do
        it { validated_by_record(:age, 14.0f32, {even: true}).should_not be_invalid }
        it { validated_by_record(:age, 13.0f32, {even: true}).should be_invalid }
      end

      describe "String" do
        it do
          expect_raises(ArgumentError) do
            validated_by_record(:age, "14", {even: true}).should_not be_invalid
          end
        end
      end

      describe "Nil" do
        it { validated_by_record(:age, nil, {even: true}).should_not be_invalid }
      end
    end

    describe "message" do
      it do
        proc = ->(record : Jennifer::Model::Translation, field : String) do
          "#{record.as(Contact).attribute(field)} #{field} invalid"
        end
        validated_by_record(:age, 11, {less_than: 3, message: proc})
          .should has_error_message(:age, "28 age invalid")
      end
    end

    pending "test allow_blank"
    {% end %}
  end
end
