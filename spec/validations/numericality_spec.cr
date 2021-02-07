require "../spec_helper"

describe Jennifer::Validations::Numericality do
  # ameba:disable Lint/UselessAssign
  described_class = Jennifer::Validations::Numericality

  describe "#validate" do
    {% begin %}
    describe "greater_than" do
      {% definition = {greater_than: 12} %}

      describe "Int32" do
        it { validated_by_record({{definition}}, 13).should_not be_invalid }
        it { validated_by_record({{definition}}, 12).should be_invalid }
      end

      describe "Int16" do
        it { validated_by_record({{definition}}, 13i64).should_not be_invalid }
        it { validated_by_record({{definition}}, 12i64).should be_invalid }
      end

      describe "Float64" do
        it { validated_by_record({{definition}}, 13.0).should_not be_invalid }
        it { validated_by_record({{definition}}, 12.0).should be_invalid }
      end

      describe "Float32" do
        it { validated_by_record({{definition}}, 13.0f32).should_not be_invalid }
        it { validated_by_record({{definition}}, 12.0f32).should be_invalid }
      end

      describe "Nil" do
        it { validated_by_record({{definition}}, nil).should_not be_invalid }
      end
    end

    describe "greater_than_or_equal_to" do
      {% definition = {greater_than_or_equal_to: 12} %}

      describe "Int32" do
        it { validated_by_record({{definition}}, 12).should_not be_invalid }
        it { validated_by_record({{definition}}, 11).should be_invalid }
      end

      describe "Int16" do
        it { validated_by_record({{definition}}, 12i64).should_not be_invalid }
        it { validated_by_record({{definition}}, 11i64).should be_invalid }
      end

      describe "Float64" do
        it { validated_by_record({{definition}}, 12.0).should_not be_invalid }
        it { validated_by_record({{definition}}, 11.0).should be_invalid }
      end

      describe "Float32" do
        it { validated_by_record({{definition}}, 12.0f32).should_not be_invalid }
        it { validated_by_record({{definition}}, 11.0f32).should be_invalid }
      end

      describe "Nil" do
        it { validated_by_record({{definition}}, nil).should_not be_invalid }
      end
    end

    describe "equal_to" do
      {% definition = {equal_to: 12} %}

      describe "Int32" do
        it { validated_by_record({{definition}}, 12).should_not be_invalid }
        it { validated_by_record({{definition}}, 11).should be_invalid }
        it { validated_by_record({{definition}}, 13).should be_invalid }
      end

      describe "Int16" do
        it { validated_by_record({{definition}}, 12i64).should_not be_invalid }
        it { validated_by_record({{definition}}, 11i64).should be_invalid }
        it { validated_by_record({{definition}}, 13i64).should be_invalid }
      end

      describe "Float64" do
        it { validated_by_record({{definition}}, 12.0).should_not be_invalid }
        it { validated_by_record({{definition}}, 11.0).should be_invalid }
        it { validated_by_record({{definition}}, 13.0).should be_invalid }
      end

      describe "Float32" do
        it { validated_by_record({{definition}}, 12.0f32).should_not be_invalid }
        it { validated_by_record({{definition}}, 11.0f32).should be_invalid }
        it { validated_by_record({{definition}}, 13.0f32).should be_invalid }
      end

      describe "Nil" do
        it { validated_by_record({{definition}}, nil).should_not be_invalid }
      end
    end

    describe "other_than" do
      {% definition = {other_than: 12} %}

      describe "Int32" do
        it { validated_by_record({{definition}}, 12).should be_invalid }
        it { validated_by_record({{definition}}, 11).should_not be_invalid }
        it { validated_by_record({{definition}}, 13).should_not be_invalid }
      end

      describe "Int16" do
        it { validated_by_record({{definition}}, 12i64).should be_invalid }
        it { validated_by_record({{definition}}, 11i64).should_not be_invalid }
        it { validated_by_record({{definition}}, 13i64).should_not be_invalid }
      end

      describe "Float64" do
        it { validated_by_record({{definition}}, 12.0).should be_invalid }
        it { validated_by_record({{definition}}, 11.0).should_not be_invalid }
        it { validated_by_record({{definition}}, 13.0).should_not be_invalid }
      end

      describe "Float32" do
        it { validated_by_record({{definition}}, 12.0f32).should be_invalid }
        it { validated_by_record({{definition}}, 11.0f32).should_not be_invalid }
        it { validated_by_record({{definition}}, 13.0f32).should_not be_invalid }
      end

      describe "Nil" do
        it { validated_by_record({{definition}}, nil).should_not be_invalid }
      end
    end

    describe "less_than" do
      {% definition = {less_than: 12} %}

      describe "Int32" do
        it { validated_by_record({{definition}}, 11).should_not be_invalid }
        it { validated_by_record({{definition}}, 12).should be_invalid }
      end

      describe "Int16" do
        it { validated_by_record({{definition}}, 11i64).should_not be_invalid }
        it { validated_by_record({{definition}}, 12i64).should be_invalid }
      end

      describe "Float64" do
        it { validated_by_record({{definition}}, 11.0).should_not be_invalid }
        it { validated_by_record({{definition}}, 12.0).should be_invalid }
      end

      describe "Float32" do
        it { validated_by_record({{definition}}, 11.0f32).should_not be_invalid }
        it { validated_by_record({{definition}}, 12.0f32).should be_invalid }
      end

      describe "Nil" do
        it { validated_by_record({{definition}}, nil).should_not be_invalid }
      end
    end

    describe "less_than_or_equal_to" do
      {% definition = {less_than_or_equal_to: 12} %}

      describe "Int32" do
        it { validated_by_record({{definition}}, 12).should_not be_invalid }
        it { validated_by_record({{definition}}, 13).should be_invalid }
      end

      describe "Int16" do
        it { validated_by_record({{definition}}, 12i64).should_not be_invalid }
        it { validated_by_record({{definition}}, 13i64).should be_invalid }
      end

      describe "Float64" do
        it { validated_by_record({{definition}}, 12.0).should_not be_invalid }
        it { validated_by_record({{definition}}, 13.0).should be_invalid }
      end

      describe "Float32" do
        it { validated_by_record({{definition}}, 12.0f32).should_not be_invalid }
        it { validated_by_record({{definition}}, 13.0f32).should be_invalid }
      end

      describe "Nil" do
        it { validated_by_record({{definition}}, nil).should_not be_invalid }
      end
    end

    describe "odd" do
      {% definition = {odd: true} %}

      describe "Int32" do
        it { validated_by_record({{definition}}, 13).should_not be_invalid }
        it { validated_by_record({{definition}}, 14).should be_invalid }
      end

      describe "Int16" do
        it { validated_by_record({{definition}}, 13i64).should_not be_invalid }
        it { validated_by_record({{definition}}, 14i64).should be_invalid }
      end

      describe "Float64" do
        it { validated_by_record({{definition}}, 13.0).should_not be_invalid }
        it { validated_by_record({{definition}}, 14.0).should be_invalid }
      end

      describe "Float32" do
        it { validated_by_record({{definition}}, 13.0f32).should_not be_invalid }
        it { validated_by_record({{definition}}, 14.0f32).should be_invalid }
      end

      describe "String" do
        it do
          expect_raises(ArgumentError) do
            validated_by_record({{definition}}, "13").should_not be_invalid
          end
        end
      end

      describe "Nil" do
        it { validated_by_record({{definition}}, nil).should_not be_invalid }
      end
    end

    describe "even" do
      describe "Int32" do
        it { validated_by_record({even: true}, 14).should_not be_invalid }
        it { validated_by_record({even: true}, 13).should be_invalid }
      end

      describe "Int16" do
        it { validated_by_record({even: true}, 14i64).should_not be_invalid }
        it { validated_by_record({even: true}, 13i64).should be_invalid }
      end

      describe "Float64" do
        it { validated_by_record({even: true}, 14.0).should_not be_invalid }
        it { validated_by_record({even: true}, 13.0).should be_invalid }
      end

      describe "Float32" do
        it { validated_by_record({even: true}, 14.0f32).should_not be_invalid }
        it { validated_by_record({even: true}, 13.0f32).should be_invalid }
      end

      describe "String" do
        it do
          expect_raises(ArgumentError) do
            validated_by_record({even: true}, "14").should_not be_invalid
          end
        end
      end

      describe "Nil" do
        it { validated_by_record({even: true}, nil).should_not be_invalid }
      end
    end

    pending "test allow_blank"
    {% end %}
  end
end
