require "../../spec_helper"

private macro quote_example(value, type_cast)
  it do
    executed = false
    value = {{value}}
    adapter.query("SELECT #{described_class.quote(value)}::{{type_cast.id}}") do |rs|
      rs.each do
        result =
          {% if type_cast == "json" || type_cast == "jsonb" %}
            rs.read(JSON::Any)
          {% else %}
            rs.read
          {% end %}
        result.should eq(value)
        executed = true
      end
    end
    executed.should be_true
  end
end

postgres_only do
  describe Jennifer::Postgres::SQLGenerator do
    described_class = Jennifer::Adapter.default_adapter.sql_generator
    adapter = Jennifer::Adapter.default_adapter

    describe ".lock_clause" do
      it "render custom query part if specified" do
        query = Contact.all.lock("FOR NO KEY UPDATE")
        sb { |io| described_class.lock_clause(io, query) }.should match(/FOR NO KEY UPDATE/)
      end
    end

    describe ".json_path" do
      criteria = Factory.build_criteria

      context "array index" do
        it "paste number without escaping" do
          s = criteria.take(1)
          described_class.json_path(s).should eq(%(#{quote_identifier("tests.f1")}->1))
        end
      end

      context "path" do
        it "wraps path into quotes" do
          s = criteria.path("{a, 1}")
          described_class.json_path(s).should eq(%(#{quote_identifier("tests.f1")}#>'{a, 1}'))
        end

        it "use arrow operator if need just first level extraction" do
          s = criteria["a"]
          described_class.json_path(s).should eq(%(#{quote_identifier("tests.f1")}->'a'))
        end
      end
    end

    describe ".parse_query" do
      it "replace placeholders with dollar numbers" do
        described_class.parse_query("asd %s qwe %s", [1, 2] of Jennifer::DBAny).should eq({"asd $1 qwe $2", [1, 2]})
      end

      it "replaces user provided argument symbols with database specific" do
        query = Contact.where { _name == sql("lower(%s)", ["john"], false) }
        described_class.parse_query(described_class.select(query), query.sql_args)[0]
          .should match(/#{reg_quote_identifier("name")} = lower\(\$1\)/m)
      end
    end

    describe ".insert_on_duplicate" do
      it "do not add on conflict columns if none present" do
        query = described_class.insert_on_duplicate("contacts", ["field1"], 1, [] of String, {} of Nil => Nil)
        query.should match(/ON CONFLICT DO NOTHING/)
      end
    end

    describe ".order_expression" do
      context "with nulls first" do
        it do
          Factory.build_criteria.asc.nulls_first.as_sql.should eq(%(#{quote_identifier("tests.f1")} ASC NULLS FIRST))
          Factory.build_criteria.desc.nulls_first.as_sql.should eq(%(#{quote_identifier("tests.f1")} DESC NULLS FIRST))
        end
      end

      context "with nulls last" do
        it do
          Factory.build_criteria.asc.nulls_last.as_sql.should eq(%(#{quote_identifier("tests.f1")} ASC NULLS LAST))
          Factory.build_criteria.desc.nulls_last.as_sql.should eq(%(#{quote_identifier("tests.f1")} DESC NULLS LAST))
        end
      end
    end

    describe "#quote" do
      quote_example(PG::Geo::Box.new(1, 2, 3, 4), :box)
      quote_example(PG::Geo::Circle.new(1, 2, 3), :circle)
      quote_example(PG::Geo::Line.new(1, 2, 3), :line)
      quote_example(PG::Geo::LineSegment.new(1, 2, 3, 4), :lseg)
      quote_example(PG::Geo::Path.new([PG::Geo::Point.new(1, 2), PG::Geo::Point.new(3, 4)], false), :path)
      quote_example(PG::Geo::Point.new(1, 2), :point)
      quote_example(PG::Geo::Polygon.new([PG::Geo::Point.new(1, 2), PG::Geo::Point.new(3, 4)]), :polygon)
      quote_example(PG::Numeric.new(1i16, 0i16, 0i16, 0i16, [1i16]), :numeric)
      quote_example([1, 2], "int[]")
      quote_example([1.0, 2.0], "float[]")
      quote_example([1.0, 2.0], "double precision[]")
      quote_example([%(this has a \\), "a"], "text[]")
      quote_example(JSON::Any.from_json({"asd" => {"asd" => [1, 2, 3], "b" => ["asd"]}}.to_json), "json")
      quote_example(JSON::Any.from_json({"asd" => {"asd" => [1, 2, 3], "b" => ["asd"]}}.to_json), "jsonb")
      quote_example(JSON::Any.from_json({ %(this has a \\) => {"b" => [%(what's your "name")]} }.to_json), "json")
      quote_example(Bytes[1, 123, 123, 34, 54], "bytea")
      quote_example(Time.utc(2010, 10, 10, 12, 34, 56), "timestamp")
      quote_example(Time.utc(2010, 10, 10, 0, 0, 0), "date")
      quote_example(nil, "unknown")
      quote_example(true, "boolean")
      quote_example(false, "boolean")
      # quote_example('c', "char")
      quote_example(%(foo), "text")
      quote_example(%(this has a \\), "text")
      quote_example(%(what's your "name"), "text")
      quote_example(1, "int")
      quote_example(1.0, "float")
      quote_example(1.0, "double precision")
    end

    describe "#quote_table" do
      it { sql_generator.quote_table("user posts").should eq(%("user posts")) }
      it { sql_generator.quote_table("user.posts").should eq(%("user"."posts")) }
    end

    describe "#quote_identifier" do
      it { sql_generator.quote_identifier("user posts").should eq(%("user posts")) }
      it { sql_generator.quote_identifier(%(what's \\ your "name")).should eq(%("what's \\ your ""name""")) }
    end
  end
end
