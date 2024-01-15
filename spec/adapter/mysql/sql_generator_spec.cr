require "../../spec_helper"

private macro quote_example(value, type_cast = nil)
  it do
    executed = false
    value = {{value}}
    query = {% if type_cast %}
        "SELECT CAST(#{described_class.quote(value)} AS {{type_cast.id}})"
      {% else %}
        "SELECT #{described_class.quote(value)}"
      {% end %}
    adapter.query(query) do |rs|
      rs.each do
        result = value.is_a?(Bool) ? rs.read(Bool) :  rs.read
        result.should eq(value)
        executed = true
      end
    end
    executed.should be_true
  end
end

mysql_only do
  describe Jennifer::Mysql::SQLGenerator do
    described_class = Jennifer::Adapter.default_adapter.sql_generator
    adapter = Jennifer::Adapter.default_adapter

    describe ".lock_clause" do
      it "render custom query part if specified" do
        query = Contact.all.lock("LOCK IN SHARE MODE")
        sb { |io| described_class.lock_clause(io, query) }.should match(/LOCK IN SHARE MODE/)
      end
    end

    describe ".json_path" do
      criteria = Factory.build_criteria

      context "array index" do
        it "converts number to proper selector" do
          s = criteria.take(1)
          described_class.json_path(s).should eq("`tests`.`f1`->\"$[1]\"")
        end
      end

      it "quotes path" do
        s = criteria.path("$[1][2]")
        described_class.json_path(s).should eq("`tests`.`f1`->\"$[1][2]\"")
      end
    end

    describe ".parse_query" do
      it "replace placeholders with question marks" do
        described_class.parse_query("asd %s qwe %s", [1, 2] of Jennifer::DBAny).should eq({"asd ? qwe ?", [1, 2]})
      end

      it "replaces user provided argument symbols with database specific" do
        query = Contact.where { _name == sql("lower(%s)", ["john"], false) }
        described_class.parse_query(described_class.select(query), query.sql_args)[0]
          .should match(/`name` = lower\(\?\)/m)
      end
    end

    describe ".order_expression" do
      context "with nulls first" do
        it do
          Factory.build_criteria.asc.nulls_first.as_sql
            .should eq("CASE WHEN `tests`.`f1` IS NULL THEN 0 ELSE 1 ASC END, `tests`.`f1` ASC")
          Factory.build_criteria.desc.nulls_first.as_sql
            .should eq("CASE WHEN `tests`.`f1` IS NULL THEN 0 ELSE 1 ASC END, `tests`.`f1` DESC")
        end
      end

      context "with nulls last" do
        it do
          Factory.build_criteria.asc.nulls_last.as_sql
            .should eq("CASE WHEN `tests`.`f1` IS NULL THEN 0 ELSE 1 DESC END, `tests`.`f1` ASC")
          Factory.build_criteria.desc.nulls_last.as_sql
            .should eq("CASE WHEN `tests`.`f1` IS NULL THEN 0 ELSE 1 DESC END, `tests`.`f1` DESC")
        end
      end
    end

    describe "#quote" do
      it "correctly escapes blob" do
        value = Bytes[1, 123, 123, 34, 54]
        adapter.exec("INSERT INTO all_types (blob_f) values(#{described_class.quote(value)})")
        AllTypeModel.all.first!.blob_f.should eq(value)
      end

      quote_example(Time.utc(2010, 10, 10, 12, 34, 56), "datetime")
      quote_example(Time.utc(2010, 10, 10, 0, 0, 0), "date")
      quote_example(nil)
      quote_example(true)
      quote_example(false)
      quote_example(%(foo))
      quote_example(%(this has a \\))
      quote_example(%(what's your "name"))
      quote_example(1)
      quote_example(1.0)

      describe "JSON::Any" do
        it "is raises exception on '\\'" do
          executed = false
          expect_raises(ArgumentError) do
            value = JSON::Any.from_json({ %(this has a \\) => 1 }.to_json)
            described_class.quote(value)
          end
        end

        it "is raises exception on '\"'" do
          executed = false
          expect_raises(ArgumentError) do
            value = JSON::Any.from_json({ %(this) => {"b" => [%(what your "name")]} }.to_json)
            described_class.quote(value)
          end
        end

        quote_example(JSON::Any.from_json({"asd" => {"asd" => [1, 2, 3], "b" => ["asd"]}}.to_json), "json")
        quote_example(JSON::Any.from_json({ %(this) => {"b" => [%(what's your name)]} }.to_json), "json")
      end
    end

    describe "#quote_table" do
      it { sql_generator.quote_table("user posts").should eq(%(`user posts`)) }
      it { sql_generator.quote_table("user.posts").should eq(%(`user`.`posts`)) }
    end

    describe "#quote_identifier" do
      it { sql_generator.quote_identifier("user posts").should eq(%(`user posts`)) }
      it { sql_generator.quote_identifier(%(what`s \\ your "name")).should eq(%(`what``s \\ your "name"`)) }
    end
  end
end
