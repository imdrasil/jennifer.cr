require "../spec_helper"

describe Jennifer::QueryBuilder::Joining do
  query = Factory.build_query

  describe "#join" do
    it "adds inner join by default" do
      q1 = query.clone
      q1.join(Address) { _tests__id == _contact_id }
      q1._joins!.map(&.type).should eq([:inner])
    end

    it "raises major table expression builder as 1st argument" do
      table_name = ""
      query.clone.join(Address) { |t| table_name = t.table; t._id }
      table_name.should eq("tests")
    end

    it "raises joined table expression builder as 2nd argument" do
      table_name = ""
      query.clone.join(Address) { |_, t| table_name = t.table; t._id }
      table_name.should eq("addresses")
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
        q._joins![0].as_sql.should match(/SELECT #{reg_quote_identifier("contacts")}/m)
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

    it "builds lateral join" do
      q1 = Factory.build_query
      q1.lateral_join(join_query, "t") { _test__id == _contact_id }
      q1._joins!.map(&.class).should eq([Jennifer::QueryBuilder::LateralJoin])
    end

    it "raises major table expression builder as 1st argument" do
      table_name = ""
      query.clone.lateral_join(join_query, "addresses") { |t| table_name = t.table; t._id }
      table_name.should eq("tests")
    end

    it "raises joined table expression builder as 2nd argument" do
      table_name = ""
      query.clone.lateral_join(join_query, "addresses") { |_, t| table_name = t.table; t._id }
      table_name.should eq("addresses")
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
        q._joins![0].as_sql.should match(/SELECT #{reg_quote_identifier("contacts")}/m)
      end
    end
  end

  describe "#left_join" do
    it "adds left join" do
      q1 = Factory.build_query
      q1.left_join(Address) { _test__id == _contact_id }
      q1._joins!.map(&.type).should eq([:left])
    end

    it "raises major table expression builder as 1st argument" do
      table_name = ""
      query.clone.left_join(Address) { |t| table_name = t.table; t._id }
      table_name.should eq("tests")
    end

    it "raises joined table expression builder as 2nd argument" do
      table_name = ""
      query.clone.left_join(Address) { |_, t| table_name = t.table; t._id }
      table_name.should eq("addresses")
    end
  end

  describe "#right_join" do
    it "adds right join" do
      q1 = Factory.build_query
      q1.right_join(Address) { _test__id == _contact_id }
      q1._joins!.map(&.type).should eq([:right])
    end

    it "raises major table expression builder as 1st argument" do
      table_name = ""
      query.clone.right_join(Address) { |t| table_name = t.table; t._id }
      table_name.should eq("tests")
    end

    it "raises joined table expression builder as 2nd argument" do
      table_name = ""
      query.clone.right_join(Address) { |_, t| table_name = t.table; t._id }
      table_name.should eq("addresses")
    end
  end
end
