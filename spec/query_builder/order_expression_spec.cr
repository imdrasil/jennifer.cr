require "../spec_helper"

describe Jennifer::QueryBuilder::OrderExpression do
  described_class = Jennifer::QueryBuilder::OrderExpression

  describe ".new" do
    it "makes RawSQL not to use brackets" do
      described_class.new(Factory.build_expression.sql("raw sql"), Jennifer::QueryBuilder::OrderExpression::Direction::ASC).as_sql.should eq("raw sql ASC")
    end
  end

  describe "#eql?" do
    context "with similar order" do
      it do
        Factory.build_criteria.asc.nulls_last.should eql(Factory.build_criteria.asc.nulls_last)
      end
    end

    context "with different null position" do
      it do
        Factory.build_criteria.asc.nulls_last.should_not eql(Factory.build_criteria.asc.nulls_first)
      end
    end

    context "with different order" do
      it do
        Factory.build_criteria.asc.should_not eql(Factory.build_criteria.desc)
      end
    end

    context "with different criteria" do
      it do
        Factory.build_criteria.asc.should_not eql(Factory.build_criteria(field: "gibbon").asc)
      end
    end
  end

  describe "#direction=" do
    context "given String" do
      it do
        order = Factory.build_criteria.asc
        order.direction = "desc"
        order.direction.desc?.should be_true
      end
    end

    context "given Symbol" do
      it do
        order = Factory.build_criteria.asc
        order.direction = :desc
        order.direction.desc?.should be_true
      end
    end

    context "given invalid order" do
      it do
        order = Factory.build_criteria.asc
        expect_raises(ArgumentError) do
          order.direction = "down"
        end
      end
    end
  end

  describe "#reverse" do
    describe "ASC -> DESC" do
      it { Factory.build_criteria.asc.reverse.direction.desc?.should be_true }
    end

    describe "DESC -> ASC" do
      it { Factory.build_criteria.desc.reverse.direction.asc?.should be_true }
    end
  end

  describe "#nulls_last" do
    it do
      Factory.build_criteria.asc.nulls_last.@null_position.last?.should be_true
    end
  end

  describe "#nulls_first" do
    it do
      Factory.build_criteria.asc.nulls_first.@null_position.first?.should be_true
    end
  end

  describe "#null_unordered" do
    it do
      Factory.build_criteria.asc.nulls_last.nulls_unordered.@null_position.none?.should be_true
    end
  end

  describe "#as_sql" do
    it do
      Factory.build_criteria.asc.as_sql.should match(/ASC/)
    end
  end

  describe "#sql_args" do
    context "with no SQL args" do
      it do
        Factory.build_criteria.asc.sql_args.empty?.should be_true
      end
    end

    context "with SQL args" do
      it do
        Factory.build_expression.sql("raw sql %s", [1]).asc.sql_args.should eq(db_array(1))
      end
    end
  end

  describe "#filterable?" do
    context "with no sSQLql args" do
      it do
        Factory.build_criteria.filterable?.should be_false
      end
    end

    context "with SQL args" do
      it do
        Factory.build_expression.sql("raw sql %s", [1]).asc.filterable?.should be_true
      end
    end
  end
end
