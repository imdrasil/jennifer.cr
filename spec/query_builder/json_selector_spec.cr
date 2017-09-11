require "../spec_helper"

describe Jennifer::QueryBuilder::JSONSelector do
  describe "#as_sql" do
    it "returns proper sql" do
      c = Factory.build_criteria(field: "some_field").take("a")
      c.as_sql.should match(/tests\.some_field->['"]a['"]/)
    end
  end
end
