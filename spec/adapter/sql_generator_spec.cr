require "../spec_helper"

describe "Jennifer::Adapter::SQLGenerator" do
  adapter = Jennifer::Adapter.adapter
  described_class = Jennifer::Adapter.adapter.sql_generator

  describe "::filter_out" do
    c2 = Factory.build_criteria

    context "with Criteria" do
      it "renders sql of criteria" do
        described_class.filter_out(c2).should eq(c2.as_sql)
      end
    end

    context "with Array" do
      it { described_class.filter_out([1, c2]).should eq("%s") }

      context "as argument container" do
        it { described_class.filter_out([1, c2], false).should eq("%s, #{c2.as_sql}") }
      end
    end

    context "anything else" do
      it "renders placeholder" do
        described_class.filter_out(1).should eq("%s")
        described_class.filter_out("s").should eq("%s")
        described_class.filter_out(false).should eq("%s")
      end
    end
  end

  describe "::select_query" do
    s = Contact.where { _age == 1 }.join(Contact) { _age == Contact._age }.order(age: :desc).limit(1)
    select_query = described_class.select(s)

    it "includes select clause" do
      select_query.should match(/#{Regex.escape(sb { |io| described_class.select_clause(io, s) })}/)
    end

    it "includes from clause" do
      select_query.should match(/#{Regex.escape(sb { |io| described_class.from_clause(io, s) })}/)
    end

    it "includes body section" do
      select_query.should match(/#{Regex.escape(sb { |io| described_class.body_section(io, s) })}/)
    end
  end

  describe "::select_clause" do
    s = Contact.all.join(Address) { _id == Contact._id }.with(:addresses)

    it "includes definitions of select fields" do
      sb { |io| described_class.select_clause(io, Contact.all.select { [now.alias("now")] }) }.should match(/SELECT NOW\(\) AS now/)
    end
  end

  describe "::from_clause" do
    it "build correct from clause" do
      sb { |io| described_class.from_clause(io, Contact.all) }.should eq("FROM contacts ")
    end
  end

  describe "::body_section" do
    s = Contact.where { _age == 1 }
               .join(Contact) { _age == Contact._age }
               .order(age: :desc)
               .limit(1)
               .having { _age > 1 }
               .group(:age)
               .lock
    # TODO: rewrite to match text instead of methods calls
    body_section = sb { |io| described_class.body_section(io, s) }
    join_clause = sb { |io| described_class.join_clause(io, s) }
    where_clause = sb { |io| described_class.where_clause(io, s.tree) }
    order_clause = sb { |io| described_class.order_clause(io, s) }
    limit_clause = sb { |io| described_class.limit_clause(io, s) }
    group_clause = sb { |io| described_class.group_clause(io, s) }
    having_clause = sb { |io| described_class.having_clause(io, s) }
    lock_clause = sb { |io| described_class.lock_clause(io, s) }

    it "includes join clause" do
      join_clause.empty?.should be_false
      body_section.should match(/#{Regex.escape(join_clause)}/)
    end

    it "includes where clause" do
      where_clause.empty?.should be_false
      body_section.should match(/#{Regex.escape(where_clause)}/)
    end

    it "includes order clause" do
      order_clause.empty?.should be_false
      body_section.should match(/#{Regex.escape(order_clause)}/)
    end

    it "includes limit clause" do
      limit_clause.empty?.should be_false
      body_section.should match(/#{Regex.escape(limit_clause)}/)
    end

    it "includes group_clause" do
      group_clause.empty?.should be_false
      body_section.should match(/#{Regex.escape(group_clause)}/)
    end

    it "includes having cluase" do
      having_clause.empty?.should be_false
      body_section.should match(/#{Regex.escape(having_clause)}/)
    end

    it "includes lock clause" do
      lock_clause.empty?.should be_false
      body_section.should match(/#{Regex.escape(lock_clause)}/)
    end
  end

  describe "::group_clause" do
    it "adds nothing if query has grouping" do
      sb { |io| described_class.group_clause(io, Contact.all) }.should_not match(/GROUP/)
    end

    it "correctly generates sql" do
      sb { |io| described_class.group_clause(io, Contact.all.group(:age)) }.should match(/GROUP BY contacts.age/)
    end
  end

  describe "::join_clause" do
    it "calls #as_sql on all parts" do
      res = Contact.all.join(Address) { _id == Address._contact_id }
                       .join(Passport) { _id == Passport._contact_id }
      sb { |io| described_class.join_clause(io, res) }.split("JOIN").size.should eq(3)
    end
  end

  describe "::where_clause" do
    context "condition exists" do
      it "includes its sql" do
        sb { |io| described_class.where_clause(io, Contact.where { _id == 1 }) }
          .should eq("WHERE contacts.id = %s ")
      end
    end

    context "conditions are empty" do
      it "returns empty string" do
        sb { |io| described_class.where_clause(io, Contact.all) }.should eq("")
      end
    end
  end

  describe "::limit_clause" do
    it "includes limit if is set" do
      sb { |io| described_class.limit_clause(io, Contact.all.limit(2)) }
        .should match(/LIMIT 2/)
    end

    it "includes offset if it is set" do
      sb { |io| described_class.limit_clause(io, Contact.all.offset(4)) }
        .should match(/OFFSET 4/)
    end
  end

  describe "::order_clause" do
    it "returns empty string if there is no orders" do
      sb { |io| described_class.order_clause(io, Contact.all) }.should eq("")
    end

    it "returns all orders" do
      sb { |s| described_class.order_clause(s, Contact.all.order(age: :desc, name: :asc)) }
        .should match(/ORDER BY contacts\.age DESC, contacts\.name ASC/)
    end
  end

  describe "::lock_clause" do
    it "renders default lock if @lock is true" do
      query = Contact.all.lock
      sb { |s| described_class.lock_clause(s, query) }.should match(/FOR UPDATE/)
    end

    it "renders nothing if not specified" do
      query = Contact.all
      sb { |s| described_class.lock_clause(s, query) }.should eq("")
    end
  end

  describe "::union_clause" do
    it "add keyword" do
      sb { |s| described_class.union_clause(s, Jennifer::Query["users"].union(Jennifer::Query["contacts"])) }.should match(/UNION/)
    end

    it "adds next query to current one" do
      query = Jennifer::Query["contacts"].union(Jennifer::Query["users"])
      sb { |s| described_class.union_clause(s, query) }.should match(Regex.new(Jennifer::Adapter.adapter.sql_generator.select(Jennifer::Query["users"])))
    end
  end

  describe "::parse_query" do
    context "with given Time object" do
      it do
        with_time_zone("Etc/GMT+1") do
          adapter.parse_query("%s", [Time.now(local_time_zone)] of Jennifer::DBAny)[1][0].as(Time)
            .should be_close(Time.utc_now, 1.second)
        end
      end
    end
  end

  describe "::escape_string" do
    it "returns prepared placeholder string" do
      described_class.escape_string(3).should eq("%s, %s, %s")
    end

    it "returns generated placeholder string" do
      described_class.escape_string(4).should eq("%s, %s, %s, %s")
    end

    it { described_class.escape_string.should eq("%s") }
  end

  describe ".order_expression" do
    context "without specifying position of null" do
      context "with raw sql" do
        it do
          Factory.build_expression.sql("some sql").asc.as_sql.should eq("some sql ASC")
          Factory.build_expression.sql("some sql").desc.as_sql.should eq("some sql DESC")
        end
      end

      it do
        Factory.build_criteria.asc.as_sql.should eq("tests.f1 ASC")
        Factory.build_criteria.desc.as_sql.should eq("tests.f1 DESC")
      end
    end
  end
end
