require "../spec_helper"

describe Jennifer::QueryBuilder::Operator do
  describe "#to_sql" do
    context "MySQL" do
      {% for op in [:<, :>, :<=, :>=, :!=] %}
        context "{{op.id}} operator" do
          it "retruns string representation" do
            operator_builder({{op}}).to_sql.should eq({{op.id.stringify}})
          end
        end
      {% end %}

      context "operator ==" do
        it "returns short" do
          operator_builder(:==).to_sql.should eq("=")
        end
      end

      context "operator =~" do
        it "returns regexp operator" do
          (criteria_builder =~ "asd").to_sql.should match(/REGEXP/)
        end
      end

      context "operator LIKE" do
        it "finds correct results" do
          contact_create(name: "Abraham")
          contact_create(name: "Johny")
          Contact.where { name.like("%oh%") }.count.should eq(1)
        end
      end
    end
  end

  describe "#sql_args" do
    it "returns empty array" do
      operator_builder.sql_args.empty?.should be_true
    end
  end
end
