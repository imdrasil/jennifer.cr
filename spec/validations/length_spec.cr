require "../spec_helper"

describe Jennifer::Validations::Length do
  # ameba:disable Lint/UselessAssign
  described_class = Jennifer::Validations::Length

  describe "#validate" do
    describe "in" do
      describe "String" do
        it { validated_by_record({in: 2..3}, "Joh", :name).should_not be_invalid }
        it { validated_by_record({in: 2..3}, "Jo", :name).should_not be_invalid }
        it { validated_by_record({in: 2...3}, "Sam", :name).should be_invalid }
        it { validated_by_record({in: 2...3}, "S", :name).should be_invalid }
      end

      describe "Array" do
        it { validated_by_record({in: 2..3}, [1, 2, 3], :name).should_not be_invalid }
        it { validated_by_record({in: 2..3}, [1, 2], :name).should_not be_invalid }
        it { validated_by_record({in: 2...3}, [1, 2, 3], :name).should be_invalid }
        it { validated_by_record({in: 2...3}, [1], :name).should be_invalid }
      end

      it { validated_by_record({in: 2..3}, nil, :name).should_not be_invalid }
    end

    describe "is" do
      describe "String" do
        it { validated_by_record({is: 3}, "Joh", :name).should_not be_invalid }
        it { validated_by_record({is: 3}, "Jo", :name).should be_invalid }
      end

      describe "Array" do
        it { validated_by_record({is: 3}, [1, 2, 3], :name).should_not be_invalid }
        it { validated_by_record({is: 3}, [1, 2], :name).should be_invalid }
      end

      it { validated_by_record({is: 3}, nil, :name).should_not be_invalid }
    end

    describe "minimum" do
      describe "String" do
        it { validated_by_record({minimum: 3}, "Joh", :name).should_not be_invalid }
        it { validated_by_record({minimum: 3}, "Jo", :name).should be_invalid }
      end

      describe "Array" do
        it { validated_by_record({minimum: 3}, [1, 2, 3], :name).should_not be_invalid }
        it { validated_by_record({minimum: 3}, [1, 2], :name).should be_invalid }
      end

      it { validated_by_record({minimum: 3}, nil, :name).should_not be_invalid }
    end

    describe "maximum" do
      describe "String" do
        it { validated_by_record({maximum: 3}, "Joh", :name).should_not be_invalid }
        it { validated_by_record({maximum: 3}, "John", :name).should be_invalid }
      end

      describe "Array" do
        it { validated_by_record({maximum: 3}, [1, 2, 3], :name).should_not be_invalid }
        it { validated_by_record({maximum: 3}, [1, 2, 3, 4], :name).should be_invalid }
      end

      it { validated_by_record({maximum: 3}, nil, :name).should_not be_invalid }
    end
  end

  pending "test allow_blank"
end
