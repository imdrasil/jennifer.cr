require "../../spec_helper"

postgres_only do
  describe Jennifer::Postgres::SQLGenerator do
    described_class = Jennifer::Adapter.adapter.sql_generator

    describe "::lock_clause" do

      it "render custom query part if specified" do
        query = Contact.all.lock("FOR NO KEY UPDATE")
        sb { |s| described_class.lock_clause(s, query) }.should match(/FOR NO KEY UPDATE/)
      end
    end

    describe ".json_path" do
      criteria = Factory.build_criteria

      context "array index" do
        it "paste number without escaping" do
          s = criteria.take(1)
          described_class.json_path(s).should eq("tests.f1->1")
        end
      end

      context "path" do
        it "wraps path into quotes" do
          s = criteria.path("{a, 1}")
          described_class.json_path(s).should eq("tests.f1#>'{a, 1}'")
        end

        it "use arrow operator if need just first level extraction" do
          s = criteria["a"]
          described_class.json_path(s).should eq("tests.f1->'a'")
        end
      end
    end

    describe "::parse_query" do
      it "replace placeholders with dollar numbers" do
        described_class.parse_query("asd %s qwe %s", [1, 2] of Jennifer::DBAny).should eq({"asd $1 qwe $2", [1, 2]})
      end

      it "replaces user provided argument symbols with database specific" do
        query = Contact.where { _name == sql("lower(%s)", ["john"], false) }
        described_class.parse_query(described_class.select(query), query.sql_args)[0].should match(/name = lower\(\$1\)/m)
      end
    end

    describe ".order_expression" do
      context "with nulls first" do
        it do
          Factory.build_criteria.asc.nulls_first.as_sql.should eq("tests.f1 ASC NULLS FIRST")
          Factory.build_criteria.desc.nulls_first.as_sql.should eq("tests.f1 DESC NULLS FIRST")
        end
      end

      context "with nulls last" do
        it do
          Factory.build_criteria.asc.nulls_last.as_sql.should eq("tests.f1 ASC NULLS LAST")
          Factory.build_criteria.desc.nulls_last.as_sql.should eq("tests.f1 DESC NULLS LAST")
        end
      end
    end
  end
end
