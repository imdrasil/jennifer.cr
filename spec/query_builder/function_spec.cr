require "../spec_helper"

Jennifer::QueryBuilder::Function.define("dummy") do
  def as_sql(generator)
    "dummy(#{operands_to_sql(generator)})"
  end
end

describe Jennifer::QueryBuilder::Function do
  describe "ExpressionBuilder context" do
    it "is accessible using defined name" do
      Factory.build_expression.dummy.as_sql.should eq("dummy()")
      Factory.build_expression.dummy(1).as_sql.should eq("dummy(%s)")
    end
  end

  describe "#set_relation" do
    pending "add" do
    end
  end

  describe "#alias_tables" do
    pending "add" do
    end
  end

  describe "#change_table" do
    pending "add" do
    end
  end

  describe "#sql_args" do
    it { DummyFunction.new(1, "asd").sql_args.should eq([1, "asd"] of Jennifer::DBAny) }
    it { DummyFunction.new.sql_args.should eq([] of Jennifer::DBAny) }
    it { DummyFunction.new(Factory.build_criteria).sql_args.should eq([] of Jennifer::DBAny) }
  end

  describe "#filterable?" do
    context "with filterable sql node" do
      it { DummyFunction.new(Factory.build_expression.sql("asd", 2)).filterable?.should be_true }
      it { DummyFunction.new(Factory.build_criteria).filterable?.should be_false }
    end

    context "with filterable argument" do
      it { DummyFunction.new(1).filterable?.should be_true }
    end

    it { DummyFunction.new.filterable?.should be_false }
  end

  # Functions ====================

  describe "LowerFunction" do
    describe "#as_sql" do
      it do
        Jennifer::QueryBuilder::LowerFunction.new("ASD").as_sql.should eq("LOWER(%s)")
      end
    end

    it do
      Factory.create_contact(name: "asd")
      Jennifer::Query["contacts"].where { _name == lower("ASD") }.exists?.should be_true
    end

    it do
      Factory.create_contact(name: "ASD")
      Jennifer::Query["contacts"].where { lower(_name) == "asd" }.exists?.should be_true
    end

    it do
      Jennifer::Query["contacts"].where { _name == lower("ASD") }.exists?.should be_false
    end
  end

  describe "UpperFunction" do
    describe "#as_sql" do
      it do
        Jennifer::QueryBuilder::UpperFunction.new("ASD").as_sql.should eq("UPPER(%s)")
      end
    end

    it do
      Factory.create_contact(name: "ASD")
      Jennifer::Query["contacts"].where { _name == upper("asd") }.exists?.should be_true
    end

    it do
      Factory.create_contact(name: "asd")
      Jennifer::Query["contacts"].where { upper(_name) == "ASD" }.exists?.should be_true
    end

    it do
      Jennifer::Query["contacts"].where { _name == upper("asd") }.exists?.should be_false
    end
  end

  describe "CurrentTimestampFunction" do
    describe "#as_sql" do
      it do
        Jennifer::QueryBuilder::CurrentTimestampFunction.new.as_sql.should eq("CURRENT_TIMESTAMP")
      end
    end

    it "doesn't fail" do
      Jennifer::Query["contacts"].where { _created_at <= current_timestamp }.exists?
    end
  end

  describe "CurrentDateFunction" do
    describe "#as_sql" do
      it do
        Jennifer::QueryBuilder::CurrentDateFunction.new.as_sql.should eq("CURRENT_DATE")
      end
    end

    it do
      Factory.create_contact
      Jennifer::Query["contacts"].select { [current_date.alias("current_d")] }.first!.current_d(Time).should eq(Time.epoch(Time.now.epoch).date)
    end
  end

  describe "CurrentTimeFunction" do
    describe "#as_sql" do
      it do
        Jennifer::QueryBuilder::CurrentTimeFunction.new.as_sql.should eq("CURRENT_TIME")
      end
    end

    it do
      Factory.create_contact
      time = Time.now
      current_t = time - time.at_beginning_of_day - 1.second
      next_t = time - time.at_beginning_of_day + 1.second

      Jennifer::Query["contacts"].where { (current_time >= current_t) & (current_time <= next_t) }.count.should eq(1)
    end
  end

  describe "NowFunction" do
    describe "#as_sql" do
      it do
        Jennifer::QueryBuilder::NowFunction.new.as_sql.should eq("NOW()")
      end
    end

    it do
      Factory.create_contact
      time = db_specific(
        mysql: -> { Time.now + Time.now.offset.seconds },
        postgres: -> { Time.utc_now }
      )
      Jennifer::Query["contacts"].select { [now.alias("now")] }.first!.now(Time).should be_close(time, 1.second)
    end
  end

  describe "ConcatFunction" do
    describe "#as_sql" do
      it do
        Jennifer::QueryBuilder::ConcatFunction.new("asd", 1).as_sql.should eq("CONCAT(%s, %s)")
      end
    end

    it do
      Factory.create_contact(name: "sur", description: "name sur")
      Jennifer::Query["contacts"].where { _description == concat(sql("'name '", false), _name) }.count.should eq(1)
    end
  end

  describe "AbsFunction" do
    describe "#as_sql" do
      it do
        Jennifer::QueryBuilder::AbsFunction.new(1).as_sql.should eq("ABS(%s)")
      end
    end

    it do
      Factory.create_facebook_profile(contact_id: -10)
      Query["profiles"].select { [abs(_contact_id).alias("id")] }.first!.id(Int).should eq(10)
    end
  end

  describe "CeilFunction" do
    describe "#as_sql" do
      it do
        Jennifer::QueryBuilder::CeilFunction.new(1).as_sql.should eq("CEIL(%s)")
      end
    end

    it do
      Factory.create_contact
      res = Query["contacts"].select { [ceil(sql("-2.1", false)).alias("v")] }.first!
      db_specific(
        mysql: -> { res.v(Int64).should eq(-2) },
        postgres: -> { res.v(PG::Numeric).should eq(-2) }
      )
    end
  end

  describe "FloorFunction" do
    describe "#as_sql" do
      it do
        Jennifer::QueryBuilder::FloorFunction.new(1).as_sql.should eq("FLOOR(%s)")
      end
    end

    it do
      Factory.create_contact
      res = Query["contacts"].select { [floor(sql("-2.1", false)).alias("v")] }.first!
      db_specific(
        mysql: -> { res.v(Int64).should eq(-3) },
        postgres: -> { res.v(PG::Numeric).should eq(-3) }
      )
    end
  end

  describe "RoundFunction" do
    describe "#as_sql" do
      it do
        Jennifer::QueryBuilder::RoundFunction.new(1).as_sql.should eq("ROUND(%s)")
      end
    end

    it do
      Factory.create_contact
      res = Query["contacts"].select { [round(sql("-2.1", false)).alias("v")] }.first!
      db_specific(
        mysql: -> { res.v(Float64).should eq(-2) },
        postgres: -> { res.v(PG::Numeric).should eq(-2) }
      )
    end
  end
end
