require "../spec_helper"

describe Jennifer::Generators::Field do
  described_class = Jennifer::Generators::Field

  describe ".new" do
    context "with bad type" do
      it do
        expect_raises(Exception) do
          described_class.new("name", "test", false)
        end
      end
    end

    context "with reference type" do
      it do
        described_class.new("name", "reference", false).nilable.should be_true
      end
    end
  end

  describe "#field_name" do
    context "with reference type" do
      it do
        described_class.new("name", "reference", false).field_name.should eq("name_id")
      end
    end

    it do
      described_class.new("name", "text", false).field_name.should eq("name")
    end
  end

  describe "#cr_type" do
    describe "id" do
      describe "bigint" do
        it do
          described_class.new("id", "bigint", false).cr_type.should eq("Primary64")
        end
      end

      describe "integer" do
        it do
          described_class.new("id", "integer", false).cr_type.should eq("Primary32")
        end
      end

      describe "custom type" do
        pending "add"
      end

      context "as nilable" do
        it do
          described_class.new("id", "bigint", true).cr_type.should eq("Primary64")
        end
      end
    end

    describe "reference" do
      it do
        described_class.new("name", "reference", false).cr_type.should eq("Int64?")
      end
    end

    describe "nilable" do
      it do
        described_class.new("name", "integer", true).cr_type.should eq("Int32?")
      end
    end
  end

  describe "#id?" do
    it do
      described_class.new("name", "integer", false).id?.should be_false
    end

    it do
      described_class.new("id", "integer", false).id?.should be_true
    end
  end

  describe "#decimal?" do
    pending "add"
  end

  describe "#reference?" do
    it do
      described_class.new("name", "integer", false).reference?.should be_false
    end

    it do
      described_class.new("name", "reference", false).reference?.should be_true
    end
  end

  describe "#timestamp?" do
    it do
      described_class.new("name", "integer", false).timestamp?.should be_false
    end

    it do
      described_class.new("created_at", "integer", false).timestamp?.should be_true
    end

    it do
      described_class.new("updated_at", "integer", false).timestamp?.should be_true
    end
  end
end
