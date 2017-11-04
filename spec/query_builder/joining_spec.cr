require "../spec_helper"

describe Jennifer::QueryBuilder::Joining do
  described_class = Jennifer::QueryBuilder::Query

  describe "#join" do
    it "adds inner join by default" do
      q1 = Factory.build_query
      q1.join(Address) { _test__id == _contact_id }
      q1._joins!.map(&.type).should eq([:inner])
    end

    context "with Query as a source" do
      it "creates proper join" do
        q = Factory.build_query
        q.join(Factory.build_query, "t1") { sql("true") }
        q._joins![0].as_sql.should match(/SELECT/m)
      end
    end

    context "with ModelQuery as a source" do
      it "creates proper join" do
        q = Factory.build_query
        q.join(Contact.where { _id == 2 }, "t1") { sql("true") }
        q._joins![0].as_sql.should match(/SELECT contacts/m)
      end
    end
  end

  describe "#lateral_join" do
    join_query = Contact.where { _id == 2 }

    it "adds inner join by default" do
      q1 = Factory.build_query
      q1.lateral_join(join_query, "t") { _test__id == _contact_id }
      q1._joins!.map(&.type).should eq([:inner])
    end

    it "builds laterla join" do
      q1 = Factory.build_query
      q1.lateral_join(join_query, "t") { _test__id == _contact_id }
      q1._joins!.map(&.class).should eq([Jennifer::QueryBuilder::LateralJoin])
    end

    context "with Query as a source" do
      it "creates proper join" do
        q = Factory.build_query
        q.lateral_join(Factory.build_query, "t1") { sql("true") }
        q._joins![0].as_sql.should match(/SELECT/m)
      end
    end

    context "with ModelQuery as a source" do
      it "creates proper join" do
        q = Factory.build_query
        q.lateral_join(join_query, "t1") { sql("true") }
        q._joins![0].as_sql.should match(/SELECT contacts/m)
      end
    end
  end

  describe "#left_join" do
    it "addes left join" do
      q1 = Factory.build_query
      q1.left_join(Address) { _test__id == _contact_id }
      q1._joins!.map(&.type).should eq([:left])
    end
  end

  describe "#right_join" do
    it "addes right join" do
      q1 = Factory.build_query
      q1.right_join(Address) { _test__id == _contact_id }
      q1._joins!.map(&.type).should eq([:right])
    end
  end
end
