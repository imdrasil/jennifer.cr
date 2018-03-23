require "../spec_helper"

describe Jennifer::Model::Authentication do
  describe "%with_authentication" do
    context "with default field names" do
      default_user = Factory.build_user

      describe "validations" do
        it do
          user = Factory.build_user
          user.password = "1" * 52
          user.should validate(:password).with("is too long (maximum is 51 characters)")
        end

        it { Factory.build_user([:with_invalid_password_confirmation]).should validate(:password).with("doesn't match Password") }
        it { Factory.build_user.should validate(:password).with("can't be blank") }
        it { Factory.build_user([:with_valid_password]).should be_valid }

        it do
          user = Factory.build_user
          user.password_digest = Crypto::Bcrypt::Password.create("password").to_s
          user.should be_valid
        end
        it do
          Factory.create_user([:with_password_digest])
          user = User.all.last!
          user.should be_valid
        end
      end

      describe "::password_digest_cost" do
        it { User.password_digest_cost.should eq(Crypto::Bcrypt::DEFAULT_COST) }
      end

      describe "#password=" do
        it do
          user = Factory.build_user
          user.password = nil
          user.password_digest.should eq("")
        end

        it do
          user = Factory.build_user
          user.password = ""
          user.password_digest.should eq("")
        end

        it do
          user = Factory.build_user
          user.password = "1" * 53
          user.password_digest.should eq("")
        end

        it do
          user = Factory.build_user
          user.password = "password"
          user.password_digest.empty?.should_not be_true
        end
      end

      describe "#authenticate" do
        it { Factory.build_user([:with_password_digest]).authenticate("gibberish").should be_nil }
        it do
          user = Factory.build_user([:with_password_digest])
          user.authenticate("password").should eq(user)
        end
      end
    end
  end
end
