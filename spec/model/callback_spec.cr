require "../spec_helper"

describe Jennifer::Model::Callback do
  describe "before_save" do
    it "is called before any save" do
      c = Factory.build_country
      c.before_save_attr.should be_false
      c.save
      c.before_save_attr.should be_true
    end
  end

  describe "after_save" do
    it "is called after any save" do
      c = Factory.build_country
      c.after_save_attr.should be_false
      c.save
      c.after_save_attr.should be_true
    end
  end

  describe "before_create" do
    it "is called before create" do
      c = Factory.build_country
      c.before_create_attr.should be_false
      c.save
      c.before_create_attr.should be_true
    end

    it "is not called before update" do
      Factory.create_country
      c = Country.all.first!
      c.name = "k2"
      c.before_create_attr.should be_false
      c.save
      c.before_create_attr.should be_false
    end

    it "stops creating if before callback raises Skip exceptions" do
      c = Factory.create_country(name: "not create")
      c.new_record?.should be_true
    end
  end

  describe "after_create" do
    it "is called after create" do
      c = Factory.build_country
      c.after_create_attr.should be_false
      c.save
      c.after_create_attr.should be_true
    end

    it "is not called after update" do
      Factory.create_country
      c = Country.all.first!
      c.name = "k2"
      c.after_create_attr.should be_false
      c.save
      c.after_create_attr.should be_false
    end
  end

  describe "before_update" do
    it "is not invoked after record creating" do
      c = Factory.create_country
      c.before_update_attr.should be_false
    end

    it "is called before create" do
      c = Factory.create_country
      c.name = "zxc"
      c.save
      c.before_update_attr.should be_true
    end

    it "stops updating if before callback raises Skip exceptions" do
      c = Factory.create_country(name: "zxc")
      c.name = "not create"
      c.save.should be_false
    end
  end

  describe "after_update" do
    it "is not invoked after record creating" do
      c = Factory.create_country
      c.after_update_attr.should be_false
    end

    it "is called after update" do
      c = Factory.create_country
      c.name = "new name zxc"
      c.save
      c.after_update_attr.should be_true
    end
  end

  describe "after_initialize" do
    it "is called after build" do
      c = CountryFactory.build
      c.after_initialize_attr.should be_true
    end

    it "is called after loading from db" do
      Factory.create_country
      c = Country.all.first!
      c.after_initialize_attr.should be_true
    end
  end

  describe "before_destroy" do
    it "is called before destroy" do
      c = Factory.create_country
      c.destroy
      c.before_destroy_attr.should be_true
    end

    it "is not called before delete" do
      c = Factory.create_country
      c.delete
      c.before_destroy_attr.should be_false
    end
  end

  describe "after_destroy" do
    it "is called after destroy" do
      c = Factory.create_country
      c.destroy
      c.after_destroy_attr.should be_true
    end

    it "is not called if before destroy callback adds error" do
      c = Factory.create_country(name: "not kill")
      c.destroy
      c.destroyed?.should be_false
      c.after_destroy_attr.should be_false
      Country.all.count.should eq(1)
    end
  end

  describe "after_validation" do
    it "is called after validation" do
      c = CountryWithValidationCallbacks.build(name: "downcased")
      c.save
      c.name.should eq("DOWNCASED")
    end

    it "is not called if record is invalid" do
      c = CountryWithValidationCallbacks.create(name: "cOuntry")
      c.errors.empty?.should be_false
      c.name.should eq("cOuntry")
    end
  end

  describe "before_validation" do
    it "is called before validation" do
      c = CountryWithValidationCallbacks.build(name: "UPCASED")
      c.save
      c.name.should eq("upcased")
    end

    it "stop creating record if skip was raised " do
      c = CountryWithValidationCallbacks.create(name: "skip")
      c.new_record?.should be_true
    end
  end

  describe "after_commit" do
    describe "create" do
      context "when model uses STI" do
        it "calls all relevant callbacks after top level commit" do
          void_transaction do
            fb = nil
            FacebookProfile.transaction do
              fb = Factory.create_facebook_profile(name: "name")
              fb.commit_callback_called?.should be_false
              fb.fb_commit_callback_called?.should be_false
            end
            fb = fb.not_nil!
            fb.commit_callback_called?.should be_true
            fb.fb_commit_callback_called?.should be_true
          end
        end
      end

      it "calls callback after top level transaction is committed" do
        void_transaction do
          country = nil
          CountryWithTransactionCallbacks.transaction do
            country = CountryWithTransactionCallbacks.create(name: "name")
            country.create_commit_callback.should be_false
          end
          country.not_nil!.create_commit_callback.should be_true
        end
      end

      it "is not called if transaction is rolled back" do
        void_transaction do
          country = nil
          CountryWithTransactionCallbacks.transaction do
            country = CountryWithTransactionCallbacks.create(name: "name")
            country.create_commit_callback.should be_false
            raise DB::Rollback.new
          end
          country.not_nil!.create_commit_callback.should be_false
        end
      end
    end

    describe "save" do
      context "when creating new record" do
        it "calls callback after top level transaction is committed" do
          void_transaction do
            country = nil
            CountryWithTransactionCallbacks.transaction do
              country = CountryWithTransactionCallbacks.create(name: "name")
              country.save_commit_callback.should be_false
            end
            country.not_nil!.save_commit_callback.should be_true
          end
        end
      end

      it "calls callback after top level transaction is committed" do
        void_transaction do
          CountryWithTransactionCallbacks.create(name: "name")
          country = CountryWithTransactionCallbacks.all.first!

          CountryWithTransactionCallbacks.transaction do
            country.name = "new_name"
            country.save
            country.save_commit_callback.should be_false
          end
          country.not_nil!.save_commit_callback.should be_true
        end
      end

      it "is not called if transaction is rolled back" do
        void_transaction do
          CountryWithTransactionCallbacks.create(name: "name")
          country = CountryWithTransactionCallbacks.all.first!

          CountryWithTransactionCallbacks.transaction do
            country.name = "another name"
            country.save
            raise DB::Rollback.new
          end
          country.not_nil!.save_commit_callback.should be_false
        end
      end
    end

    describe "update" do
      context "when creating new record" do
        it "doesn't calls callbacks after top level transaction is committed" do
          void_transaction do
            country = nil
            CountryWithTransactionCallbacks.transaction do
              country = CountryWithTransactionCallbacks.create(name: "name")
            end
            country.not_nil!.update_commit_callback.should be_false
          end
        end
      end

      it "calls callback after top level transaction is committed" do
        void_transaction do
          CountryWithTransactionCallbacks.create(name: "name")
          country = CountryWithTransactionCallbacks.all.first!

          CountryWithTransactionCallbacks.transaction do
            country.name = "new_name"
            country.save
            country.update_commit_callback.should be_false
          end
          country.not_nil!.update_commit_callback.should be_true
        end
      end

      it "is not called if transaction is rolled back" do
        void_transaction do
          CountryWithTransactionCallbacks.create(name: "name")
          country = CountryWithTransactionCallbacks.all.first!

          CountryWithTransactionCallbacks.transaction do
            country.name = "another name"
            country.save
            raise DB::Rollback.new
          end
          country.not_nil!.update_commit_callback.should be_false
        end
      end
    end

    describe "destroy" do
      it "calls callback after top level transaction is committed" do
        void_transaction do
          country = CountryWithTransactionCallbacks.create(name: "name")

          CountryWithTransactionCallbacks.transaction do
            country.destroy
            country.destroy_commit_callback.should be_false
          end
          country.not_nil!.destroy_commit_callback.should be_true
        end
      end

      it "is not called if transaction is rolled back" do
        void_transaction do
          country = CountryWithTransactionCallbacks.create(name: "name")

          CountryWithTransactionCallbacks.transaction do
            country.destroy
            country.destroy_commit_callback.should be_false
            raise DB::Rollback.new
          end
          country.not_nil!.destroy_commit_callback.should be_false
        end
      end
    end
  end

  describe "after_rollback" do
    describe "create" do
      it "doesn't call callback after top level transaction is committed" do
        void_transaction do
          country = nil
          CountryWithTransactionCallbacks.transaction do
            country = CountryWithTransactionCallbacks.create(name: "name")
          end
          country.not_nil!.create_rollback_callback.should be_false
        end
      end

      it "called if transaction is rolled back" do
        void_transaction do
          country = nil
          CountryWithTransactionCallbacks.transaction do
            country = CountryWithTransactionCallbacks.create(name: "name")
            raise DB::Rollback.new
          end
          country.not_nil!.create_rollback_callback.should be_true
        end
      end
    end

    describe "update" do
      it "doesn't call callback after top level transaction is committed" do
        void_transaction do
          country = CountryWithTransactionCallbacks.create(name: "name")
          country.name = "new name"
          country.save
          country.not_nil!.update_rollback_callback.should be_false
        end
      end

      it "called if transaction is rolled back" do
        void_transaction do
          country = CountryWithTransactionCallbacks.create(name: "name")
          CountryWithTransactionCallbacks.transaction do
            country.name = "new name"
            country.save
            raise DB::Rollback.new
          end
          country.not_nil!.update_rollback_callback.should be_true
        end
      end
    end

    describe "save" do
      context "when creating new record" do
        it "calls callback after top level transaction is rolled back" do
          void_transaction do
            country = nil
            CountryWithTransactionCallbacks.transaction do
              country = CountryWithTransactionCallbacks.create(name: "name")
              raise DB::Rollback.new
            end
            country.not_nil!.save_rollback_callback.should be_true
          end
        end
      end

      it "doesn't call callback after top level transaction is committed" do
        void_transaction do
          CountryWithTransactionCallbacks.create(name: "name")
          country = CountryWithTransactionCallbacks.all.first!

          CountryWithTransactionCallbacks.transaction do
            country.name = "new_name"
            country.save
          end
          country.not_nil!.save_rollback_callback.should be_false
        end
      end

      it "calls if transaction is rolled back" do
        void_transaction do
          CountryWithTransactionCallbacks.create(name: "name")
          country = CountryWithTransactionCallbacks.all.first!

          CountryWithTransactionCallbacks.transaction do
            country = CountryWithTransactionCallbacks.create(name: "name")
            raise DB::Rollback.new
          end
          country.not_nil!.save_rollback_callback.should be_true
        end
      end
    end

    describe "destroy" do
      it "doesn't call callback after top level transaction is committed" do
        void_transaction do
          country = CountryWithTransactionCallbacks.create(name: "name")

          CountryWithTransactionCallbacks.transaction do
            country.destroy
          end
          country.not_nil!.destroy_rollback_callback.should be_false
        end
      end

      it "calls callbacks if transaction is rolled back" do
        void_transaction do
          country = CountryWithTransactionCallbacks.create(name: "name")

          CountryWithTransactionCallbacks.transaction do
            country.destroy
            raise DB::Rollback.new
          end
          country.not_nil!.destroy_rollback_callback.should be_true
        end
      end
    end
  end

  context "inherited" do
    it "is also invoked" do
      Factory.create_contact.super_class_callback_called?.should be_true
    end
  end
end
