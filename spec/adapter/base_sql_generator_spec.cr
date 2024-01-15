require "../spec_helper"

describe Jennifer::Adapter::BaseSQLGenerator do
  adapter = Jennifer::Adapter.default_adapter
  described_class = Jennifer::Adapter.default_adapter.sql_generator
  expression_builder = Factory.build_expression

  describe ".filter_out" do
    c2 = Factory.build_criteria

    context "with Criteria" do
      it "renders SQL of criteria" do
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

  describe ".select_query" do
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

  describe ".select_clause" do
    it "includes definitions of select fields" do
      sb { |io| described_class.select_clause(io, Contact.all.select { [now.alias("now")] }) }.should match(/SELECT NOW\(\) AS now/)
    end
  end

  describe ".from_clause" do
    context "with given table name" do
      it { sb { |io| described_class.from_clause(io, "contacts") }.should eq("FROM contacts ") }
    end

    context "with non-empty table name" do
      it { sb { |io| described_class.from_clause(io, Jennifer::Query["contacts"]) }.should eq("FROM #{quote_identifier("contacts")} ") }
    end

    context "with query that has FROM set to string" do
      it { sb { |io| described_class.from_clause(io, Contact.all.from("here")) }.should eq("FROM here") }
    end

    context "with query that has FROM set to query" do
      it do
        sb { |io| described_class.from_clause(io, Contact.all.from(Contact.all)) }
          .should eq(%(FROM ( SELECT #{quote_identifier("contacts")}.* FROM #{quote_identifier("contacts")}  ) ))
      end
    end

    context "with empty table" do
      it { sb { |io| described_class.from_clause(io, Jennifer::Query[""]) }.should be_empty }
    end
  end

  describe ".body_section" do
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

  describe ".group_clause" do
    it "adds nothing if query has grouping" do
      sb { |io| described_class.group_clause(io, Contact.all) }.should_not match(/GROUP/)
    end

    it "correctly generates SQL" do
      sb { |io| described_class.group_clause(io, Contact.all.group(:age)) }
        .should match(/GROUP BY #{reg_quote_identifier("contacts.age")}/)
    end
  end

  describe ".join_clause" do
    context "with multiple components" do
      it "calls #as_sql on all parts" do
        res = Contact.all
          .join(Address) { _contact_id == Contact._id }
          .join(Passport) { _contact_id == Contact._id }
        join_clause(res).split("JOIN").size.should eq(3)
      end
    end

    context "with alias" do
      it do
        query = Contact.all.join(Address, "some_table") { |t| _contact_id == t._id }
        join_clause(query)
          .should eq(%(JOIN #{quote_identifier("addresses")} #{quote_identifier("some_table")} ON #{quote_identifier("some_table.contact_id")} = #{quote_identifier("contacts.id")}\n))
      end
    end

    describe "RIGHT" do
      it do
        query = Contact.all.right_join(Address) { |t| _contact_id == t._id }
        join_clause(query)
          .should eq(%(RIGHT JOIN #{quote_identifier("addresses")} ON #{quote_identifier("addresses.contact_id")} = #{quote_identifier("contacts.id")}\n))
      end
    end

    describe "LEFT" do
      it do
        query = Contact.all.left_join(Address) { |t| _contact_id == t._id }
        join_clause(query)
          .should eq(%(LEFT JOIN #{quote_identifier("addresses")} ON #{quote_identifier("addresses.contact_id")} = #{quote_identifier("contacts.id")}\n))
      end
    end

    describe "INNER" do
      it do
        query = Contact.all.join(Address) { |t| _contact_id == t._id }
        join_clause(query)
          .should eq(%(JOIN #{quote_identifier("addresses")} ON #{quote_identifier("addresses.contact_id")} = #{quote_identifier("contacts.id")}\n))
      end
    end

    describe "LATERAL" do
      it do
        query = Contact.all.lateral_join(Address.all, "some_table") { |t| _contact_id == t._id }
        sub_query = %(SELECT #{quote_identifier("addresses")}.* FROM #{quote_identifier("addresses")} )
        join_clause(query)
          .should eq("JOIN LATERAL (#{sub_query}) #{quote_identifier("some_table")} ON #{quote_identifier("some_table.contact_id")} = #{quote_identifier("contacts.id")}\n")
      end
    end
  end

  describe ".where_clause" do
    context "condition exists" do
      it "includes its SQL" do
        sb { |io| described_class.where_clause(io, Contact.where { _id == 1 }) }
          .should eq(%(WHERE #{quote_identifier("contacts.id")} = %s ))
      end
    end

    context "conditions are empty" do
      it "returns empty string" do
        sb { |io| described_class.where_clause(io, Contact.all) }.should eq("")
      end
    end
  end

  describe ".limit_clause" do
    it "includes limit if is set" do
      sb { |io| described_class.limit_clause(io, Contact.all.limit(2)) }
        .should match(/LIMIT 2/)
    end

    it "includes offset if it is set" do
      sb { |io| described_class.limit_clause(io, Contact.all.offset(4)) }
        .should match(/OFFSET 4/)
    end
  end

  describe ".order_clause" do
    it "returns empty string if there is no orders" do
      sb { |io| described_class.order_clause(io, Contact.all) }.should eq("")
    end

    it "returns all orders" do
      sb { |io| described_class.order_clause(io, Contact.all.order(age: :desc, name: :asc)) }
        .should match(/ORDER BY #{reg_quote_identifier("contacts.age")} DESC, #{reg_quote_identifier("contacts.name")} ASC/)
    end
  end

  describe ".lock_clause" do
    it "renders default lock if @lock is true" do
      query = Contact.all.lock
      sb { |io| described_class.lock_clause(io, query) }.should match(/FOR UPDATE/)
    end

    it "renders nothing if not specified" do
      query = Contact.all
      sb { |io| described_class.lock_clause(io, query) }.should eq("")
    end
  end

  describe ".union_clause" do
    describe "ALL" do
      it do
        sb { |io| described_class.union_clause(io, Query["contacts"].union(Query["users"], true)) }
          .should match(/UNION ALL /)
      end
    end

    it "add keyword" do
      sb { |io| described_class.union_clause(io, Jennifer::Query["users"].union(Jennifer::Query["contacts"])) }
        .should match(/UNION/)
    end

    it "adds next query to current one" do
      query = Jennifer::Query["contacts"].union(Jennifer::Query["users"])
      sb { |io| described_class.union_clause(io, query) }
        .should match(Regex.new(sql_generator.select(Jennifer::Query["users"])))
    end
  end

  describe ".parse_query" do
    context "with given Time object" do
      it "converts time to UTC" do
        with_time_zone("Etc/GMT+1") do
          adapter.parse_query("%s", [Time.local(local_time_zone)] of Jennifer::DBAny)[1][0].as(Time)
            .should be_close(Time.utc, 1.second)
        end
      end

      it "ignores times zone if .time_zone_aware_attributes config is set to false" do
        Jennifer::Config.time_zone_aware_attributes = false
        with_time_zone("Etc/GMT+1") do
          time = Time.local(local_time_zone)
          adapter.parse_query("%s", [time] of Jennifer::DBAny)[1][0].as(Time)
            .should eq(time)
        end
      end
    end
  end

  describe ".escape_string" do
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
      context "with raw SQL" do
        it do
          Factory.build_expression.sql("some sql").asc.as_sql.should eq("some sql ASC")
          Factory.build_expression.sql("some sql").desc.as_sql.should eq("some sql DESC")
        end
      end

      it do
        Factory.build_criteria.asc.as_sql.should eq(%(#{quote_identifier("tests.f1")} ASC))
        Factory.build_criteria.desc.as_sql.should eq(%(#{quote_identifier("tests.f1")} DESC))
      end
    end
  end

  describe ".with_clause" do
    describe "recursive" do
      it do
        query = Jennifer::Query["contacts"].with("test", Contact.all, true)
        expected_sql = "WITH RECURSIVE test AS (SELECT #{quote_identifier("contacts")}.* FROM #{quote_identifier("contacts")} ) "
        sb { |io| described_class.with_clause(io, query) }.should eq(expected_sql)
      end
    end

    describe "multiple recursive" do
      it do
        query = Jennifer::Query["contacts"].with("test", Contact.all, true).with("test2", Address.all, true)
        expected_sql = %(WITH RECURSIVE test AS (SELECT #{quote_identifier("contacts")}.* FROM #{quote_identifier("contacts")} ) , test2 AS (SELECT #{quote_identifier("addresses")}.* FROM #{quote_identifier("addresses")} ) )
        sb { |io| described_class.with_clause(io, query) }.should eq(expected_sql)
      end
    end

    context "with multiple expressions" do
      it do
        query = Jennifer::Query["contacts"].with("test", Contact.all).with("test 2", Contact.all)
        expected_sql = "WITH test AS (SELECT #{quote_identifier("contacts")}.* FROM #{quote_identifier("contacts")} ) , " \
                       "test 2 AS (SELECT #{quote_identifier("contacts")}.* FROM #{quote_identifier("contacts")} ) "
        sb { |io| described_class.with_clause(io, query) }.should eq(expected_sql)
      end

      it "hoists the RECURSIVE keyword to the query beginning" do
        query = Jennifer::Query["contacts"].with("test", Contact.all).with("test 2", Contact.all, true)
        expected_sql = "WITH RECURSIVE test AS (SELECT #{quote_identifier("contacts")}.* FROM #{quote_identifier("contacts")} ) , " \
                       "test 2 AS (SELECT #{quote_identifier("contacts")}.* FROM #{quote_identifier("contacts")} ) "
        sb { |io| described_class.with_clause(io, query) }.should eq(expected_sql)
      end
    end
  end

  describe ".cast_expression" do
    it do
      described_class.cast_expression(expression_builder.sql("'2000-10-20'", false), "DATE")
        .should eq("CAST('2000-10-20' AS DATE)")
      described_class.cast_expression(expression_builder._date, "DATE")
        .should eq(%(CAST(#{quote_identifier("tests.date")} AS DATE)))
    end
  end
end
