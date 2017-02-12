require "./spec_helper"
require "../examples/migrations/*"
require "./models"

describe Jennifer do
  it "works" do
    # Contact.create({:name => "John Doe", :age => 30}).id
    # t = Contact.create({:name => "Sarah", :age => 33})
    # puts Contact.all.count
    # Address.create(main: true, street: "Some st. 145", contact_id: t.id)
    # Address.create({:main => false, :street => "Some st. 5", :contact_id => t.id})
    # # Contact.where { id > 15 }.delete TODO: fix this
    # puts Address.all.count
    # # puts Passport.create(enn: "d", contact_id: 2).enn
    # a = Contact.all.join(Address) { id == Address.c("contact_id") }.with(:addresses).to_a
    # puts Contact.all.left_join(Address) { id == Address.c("contact_id") }.with(:addresses).select_query
    # puts a
  end
end

# abstract class BaseModel
# end

# class AnotherModel < BaseModel
#  extend Search
#  property id
#  @id = 1
#  scope :test, [:a, :b, :c], {c("f3") == a + b + c}
# end

# class MyModel < BaseModel
#  extend Search
#  property id
#  @id = 1
#  has_many :another_models, AnotherModel, request: {AnotherModel.c("my_model_id") == c("id")}
# end

# q = MyModel.where { (c("id") == 1) & ((c("f") < 123) | (c("a") == 2)) & (c("f") == 2) }
# puts q.where { c("qwe") == "qwe" }.to_s
# puts MyModel.where { AnotherModel.test }.to_s
# puts MyModel.new.another_models.to_sql
# puts MyModel.where { (c("f1") == 1) | (c("f2") > 2) }
#            .join(AnotherModel) { AnotherModel.c("id") != c("another_id") }
#            .where { AnotherModel.test(1, 2, 3) }.to_sql
# puts q.to_s
