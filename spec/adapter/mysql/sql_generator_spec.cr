require "../../spec_helper"

mysql_only do
  describe Jennifer::Mysql::SQLGenerator do
    described_class = Jennifer::Adapter.adapter.sql_generator

    describe "::lock_clause" do
      it "render custom query part if specified" do
        query = Contact.all.lock("LOCK IN SHARE MODE")
        sb { |s| described_class.lock_clause(s, query) }.should match(/LOCK IN SHARE MODE/)
      end
    end

    describe ".json_path" do
      criteria = Factory.build_criteria

      context "array index" do
        it "converts number to proper selector" do
          s = criteria.take(1)
          described_class.json_path(s).should eq("tests.f1->\"$[1]\"")
        end
      end

      it "quotes path" do
        s = criteria.path("$[1][2]")
        described_class.json_path(s).should eq("tests.f1->\"$[1][2]\"")
      end
    end

    describe "::parse_query" do
      it "replace placeholders with question marks" do
        described_class.parse_query("asd %s qwe %s", [1, 2] of Jennifer::DBAny).should eq({"asd ? qwe ?", [1, 2]})
      end

      it "replaces user provided argument symbols with database specific" do
        query = Contact.where { _name == sql("lower(%s)", ["john"], false) }
        described_class.parse_query(described_class.select(query), query.sql_args)[0].should match(/name = lower\(\?\)/m)
      end
    end

    describe ".order_expression" do
      context "with nulls first" do
        it do
          Factory.build_criteria.asc.nulls_first.as_sql.should eq("CASE WHEN tests.f1 IS NULL THEN 0 ELSE 1 ASC END, tests.f1 ASC")
          Factory.build_criteria.desc.nulls_first.as_sql.should eq("CASE WHEN tests.f1 IS NULL THEN 0 ELSE 1 ASC END, tests.f1 DESC")
        end
      end

      context "with nulls last" do
        it do
          Factory.build_criteria.asc.nulls_last.as_sql.should eq("CASE WHEN tests.f1 IS NULL THEN 0 ELSE 1 DESC END, tests.f1 ASC")
          Factory.build_criteria.desc.nulls_last.as_sql.should eq("CASE WHEN tests.f1 IS NULL THEN 0 ELSE 1 DESC END, tests.f1 DESC")
        end
      end
    end
  end
end
