require "../spec_helper"

class SimplifiedProfile < ApplicationRecord
  mapping({
    id:   Primary64,
    type: String,
  }, false)
end

class TwitterProfileWithDC < SimplifiedProfile
  mapping(
    email: String?
  )
end

class ProfileWithConverter < SimplifiedProfile
  mapping(
    details: {type: JSON::Any, convert: Jennifer::Model::JSONConverter}
  )
end

describe Jennifer::Model::STIMapping do
  describe "%sti_mapping" do
    context "columns metadata" do
      it "sets constant" do
        FacebookProfile::COLUMNS_METADATA.is_a?(NamedTuple).should be_true
      end

      it "copies data from superclass" do
        id = FacebookProfile::COLUMNS_METADATA[:id]
        id.is_a?(NamedTuple).should be_true
        id[:type].should eq(Int64?)
        id[:parsed_type].should eq("::Union(Int64, ::Nil)")
      end

      it "copies column aliases fro superclass" do
        name = Book::COLUMNS_METADATA[:name]
        name.is_a?(NamedTuple).should be_true
        name[:type].should eq(String)
        name[:column].should eq("title")
      end
    end

    describe ".columns_tuple" do
      it "returns named tuple mith column metedata" do
        metadata = FacebookProfile.columns_tuple
        metadata.is_a?(NamedTuple).should be_true
        metadata[:uid].is_a?(NamedTuple).should be_true
        metadata[:uid][:type].should eq(String?)
        metadata[:uid][:parsed_type].should eq("::Union(String, ::Nil)")
      end

      it "returns named tuple that also contains column aliases configs" do
        metadata = Article.columns_tuple
        metadata.is_a?(NamedTuple).should be_true
        metadata[:size].is_a?(NamedTuple).should be_true
        metadata[:size][:type].should eq(Int32?)
        metadata[:size][:column].should eq("pages")
      end
    end

    context "types" do
      context "nillable" do
        context "using ? without named tuple" do
          it "parses type as nillable" do
            typeof(Factory.build_facebook_profile.uid).should eq(String?)
          end
        end

        context "using :null option" do
          it "parses type as nillable" do
            typeof(Factory.build_twitter_profile.email).should eq(String?)
          end
        end
      end
    end

    describe "default constructor" do
      context "when all child fields have a default value" do
        context "when superclass has only `type` field without default value" do
          it "sets WITH_DEFAULT_CONSTRUCTOR to true" do
            TwitterProfileWithDC::WITH_DEFAULT_CONSTRUCTOR.should be_true
          end

          it "passes type to parent constructor" do
            TwitterProfileWithDC.new.type.should eq("TwitterProfileWithDC")
          end
        end

        it "doesn't define default constructor if all fields are nillable or have default values" do
          TwitterProfile::WITH_DEFAULT_CONSTRUCTOR.should be_false
        end
      end
    end
  end

  describe "#initialize" do
    context "ResultSet" do
      it "properly loads from db" do
        f = Factory.create_facebook_profile(uid: "1111", login: "my_login")
        res = FacebookProfile.find!(f.id)
        res.uid.should eq("1111")
        res.login.should eq("my_login")
      end

      it "properly maps aliased columns in superclass" do
        b = Book.create(
          name: "HowToMapDbStuff?",
          version: 1,
          publisher: "DbStuffMapper",
          pages: 19_000
        )
        b = Book.find!(b.id)
        b.name.should eq "HowToMapDbStuff?"
        b.pages.should eq 19_000
      end

      it "properly maps aliased columns in subclass" do
        a = Article.create(
          name: "100DatabaseTypesYouDidNotKnowAbout",
          version: 3,
          publisher: "DbStuffMapper",
          size: 12
        )
        a = Article.find!(a.id)
        a.name.should eq "100DatabaseTypesYouDidNotKnowAbout"
        a.size.should eq 12
      end
    end

    context "hash" do
      it "properly loads from hash" do
        f = FacebookProfile.new({:login => "asd", :uid => "uid"})
        f.type.should eq("FacebookProfile")
        f.login.should eq("asd")
        f.uid.should eq("uid")
      end

      it "builds proper subclass from symbol hash" do
        f = Profile.new({:login => "asd", :uid => "uid", :type => "FacebookProfile"})
        f.should be_a(FacebookProfile)

        f = f.as(FacebookProfile)
        f.type.should eq("FacebookProfile")
        f.login.should eq("asd")
        f.uid.should eq("uid")
      end

      it "builds proper subclass from string hash" do
        f = Profile.new({"login" => "asd", "uid" => "uid", "type" => "FacebookProfile"})
        f.should be_a(FacebookProfile)

        f = f.as(FacebookProfile)
        f.type.should eq("FacebookProfile")
        f.login.should eq("asd")
        f.uid.should eq("uid")
      end

      it "builds proper subclass from named tuple" do
        f = Profile.new({login: "asd", email: "test@email.co", type: "TwitterProfile"})
        f.should be_a(TwitterProfile)

        f = f.as(TwitterProfile)
        f.type.should eq("TwitterProfile")
        f.login.should eq("asd")
        f.email.should eq("test@email.co")
      end

      it "properly loads aliased columns in superclass" do
        b = Book.new({
          :name      => "HowToMapDbStuff?",
          :version   => 2,
          :publisher => "DbStuffMapper",
          :pages     => 19_000,
        })
        b.name.should eq "HowToMapDbStuff?"
        b.pages.should eq 19_000
      end

      it "properly maps aliased columns in subclass" do
        a = Article.new({
          :name      => "101DatabaseTypesYouDidNotKnowAbout",
          :version   => 1,
          :publisher => "DbStuffMapper",
          :size      => 14,
        })
        a.name.should eq "101DatabaseTypesYouDidNotKnowAbout"
        a.size.should eq 14
      end
    end
  end

  describe ".field_names" do
    it "returns all fields" do
      FacebookProfile.field_names
        .should match_array(%w(login uid type contact_id id virtual_child_field virtual_parent_field))
    end

    it "does not return aliased columns of the superclass" do
      BlogPost.field_names.should match_array(%w(id name version publisher type url created_at))
    end

    it "does not return aliased columns of the subclass" do
      Article.field_names.should match_array(%w(id name version publisher type size))
    end
  end

  describe ".column_names" do
    it "returns fields from current and parent models" do
      FacebookProfile.column_names.should match_array(%w(login uid type contact_id id))
    end

    it "doesn't include virtual fields" do
      FacebookProfile.column_names.should match_array(%w(login uid type contact_id id))
    end
  end

  describe ".all" do
    it "generates correct query" do
      q = FacebookProfile.all
      q.as_sql.should match(/#{reg_quote_identifier("profiles.type")} = %s/)
      q.sql_args.should eq(db_array("FacebookProfile"))
    end

    it "generates correct queries for tables with column aliases" do
      q = Article.all
      q.as_sql
        .should match(/#{reg_quote_identifier("publications.type")} = %s/)
      q.sql_args.should eq db_array("Article")
    end
  end

  describe "#to_h" do
    it "sets all fields" do
      r = Factory.build_facebook_profile(uid: "1111", login: "my_login").to_h
      r.keys.should eq(%i(id login contact_id type uid))
      r[:login].should eq("my_login")
      r[:type].should eq("FacebookProfile")
      r[:uid].should eq("1111")
    end

    it "sets fields with column aliases in superclasses" do
      b = BlogPost.new({
        name:      "ASimpleDbMappingTutorial",
        version:   1,
        publisher: "ATutorialPage",
        url:       "an.url.com",
      }).to_h

      b.keys.should eq(%i(id name version publisher type url))
      b[:name].should eq "ASimpleDbMappingTutorial"
      b[:version].should eq 1
      b[:type].should eq "BlogPost"
      b[:url].should eq "an.url.com"
    end

    it "sets fields with column aliases in subclasses" do
      a = Article.new({
        name:      "AMeasureOnHowMuchDbMappingStuffThereIs",
        version:   1,
        publisher: "MeasuringAllDay",
        size:      19,
      }).to_h

      a.keys.should eq(%i(id name version publisher type size))
      a[:name].should eq "AMeasureOnHowMuchDbMappingStuffThereIs"
      a[:version].should eq 1
      a[:type].should eq "Article"
      a[:size].should eq 19
    end
  end

  describe "#to_str_h" do
    it "sets all fields" do
      r = Factory.build_facebook_profile(uid: "1111", login: "my_login").to_str_h
      r.keys.should eq(%w(id login contact_id type uid))
      r["login"].should eq("my_login")
      r["type"].should eq("FacebookProfile")
      r["uid"].should eq("1111")
    end

    it "sets fields with column aliases in superclasses" do
      b = BlogPost.new({
        name:      "AGuideForSpecTesting",
        version:   99,
        publisher: "SpecTestingersLegion",
        url:       "spec.tests.com",
      }).to_str_h
      b.keys.should eq(%w(id name version publisher type url))
      b["name"].should eq "AGuideForSpecTesting"
      b["type"].should eq "BlogPost"
      b["url"].should eq "spec.tests.com"
    end

    it "sets fields with column aliases in subclasses" do
      b = Article.new({
        name:      "DealingWithSpecsInORMapping",
        version:   99,
        publisher: "SpecTestingersLegion",
        size:      3,
      }).to_str_h
      b.keys.should eq(%w(id name version publisher type size))
      b["name"].should eq "DealingWithSpecsInORMapping"
      b["type"].should eq "Article"
      b["size"].should eq 3
    end
  end

  describe "#update_column" do
    it "properly updates given attribute" do
      p = Factory.create_facebook_profile(uid: "1111")
      p.update_column(:uid, "2222")
      p.uid.should eq("2222")
      p.reload.uid.should eq("2222")
    end

    it "properly updates and maps column aliases" do
      b = BlogPost.create(
        name: "NotAnotherBlogPost",
        version: 3,
        publisher: "NoMoreBlogPosts",
        url: "www.blogpost.ing"
      )
      b.update_column(:title, "YesAnotherBlogPost")
      b.name.should eq("YesAnotherBlogPost")
      b.reload.name.should eq("YesAnotherBlogPost")
    end
  end

  describe "#update_columns" do
    context "updating attributes described in child model" do
      it "properly updates them" do
        p = Factory.create_facebook_profile(uid: "1111")
        p.update_columns({:uid => "2222"})
        p.uid.should eq("2222")
        p.reload.uid.should eq("2222")
      end

      it "propertly maps column aliases" do
        a = Article.create(
          name: "NotAnotherArticle",
          version: 99,
          publisher: "NoMoreArticles",
          size: 13
        )
        a.update_column(:pages, 14)
        a.size.should eq 14
        a.reload.size.should eq 14
      end
    end

    context "updating attributes described in parent model" do
      it "properly updates them" do
        p = Factory.create_facebook_profile(login: "111")
        p.update_columns({:login => "222"})
        p.login.should eq("222")
        p.reload.login.should eq("222")
      end

      it "propertly maps column aliases" do
        b = Book.create(
          name: "BooksAreSuperiorToArticles",
          version: 3,
          publisher: "UnionOfBookEnthusiasts",
          pages: 290
        )
        b.update_column(:title, "BooksAreSuperiorToArticlesAndBlogPosts")
        b.name.should eq "BooksAreSuperiorToArticlesAndBlogPosts"
        b.reload.name.should eq "BooksAreSuperiorToArticlesAndBlogPosts"
      end
    end

    context "updating own and inherited attributes" do
      it "properly updates them" do
        p = Factory.create_facebook_profile(login: "111", uid: "2222")
        p.update_columns({:login => "222", :uid => "3333"})
        p.login.should eq("222")
        p.uid.should eq("3333")
        p.reload
        p.login.should eq("222")
        p.uid.should eq("3333")
      end

      it "propertly maps column aliases" do
        a = Article.create(
          name: "HowAboutStoppingThisMess?",
          version: 4,
          publisher: "FedUpFederation",
          size: 2
        )
        a.update_columns({:title => "HowAboutNeverStoppingThisMess?", :pages => 3})
        a.name.should eq "HowAboutNeverStoppingThisMess?"
        a.size.should eq 3
        a.reload
        a.name.should eq "HowAboutNeverStoppingThisMess?"
        a.size.should eq 3
      end
    end

    it "raises exception if any given attribute is not exists" do
      p = Factory.create_facebook_profile(login: "111")
      expect_raises(Jennifer::BaseException) do
        p.update_columns({:asd => "222"})
      end
    end

    it "allows access via maped columns" do
      b = Book.create(
        name: "Necronomicon",
        version: 13,
        publisher: "SomePublisher",
        pages: 1299
      )
      b.update_columns({:title => "Necronnnnomicon"})
      b.name.should eq "Necronnnnomicon"
    end

    it "raises an exception when mapped columns of the subclass are accessed" do
      a = Article.create(
        name: "TheHorrorAtRedHook",
        version: 2,
        publisher: "SomePublisher",
        size: 14
      )
      expect_raises(Jennifer::BaseException) do
        a.update_columns({:size => 17})
      end
    end
  end

  describe "#attribute" do
    it "returns virtual attribute" do
      f = Factory.build_facebook_profile(uid: "111", login: "my_login")
      f.virtual_child_field = 2
      f.attribute(:virtual_child_field).should eq(2)
    end

    it "should ignore column mappings of virtual fields" do
      b = BlogPost.new({
        name:      "AWebVersionOfInTheHillsTheCities",
        version:   5,
        publisher: "RandomBlogger",
        url:       "www.random-blog.blog",
      })
      timestamp = Time.utc
      b.created_at = timestamp
      b.attribute(:created_at).should eq timestamp
    end

    it "returns own attribute" do
      f = Factory.build_facebook_profile(uid: "111", login: "my_login")
      f.attribute("uid").should eq("111")
    end

    it "returns parent attribute" do
      f = Factory.build_facebook_profile(uid: "111", login: "my_login")
      f.attribute("login").should eq("my_login")
    end
  end

  describe "#attribute_before_typecast" do
    it "should ignore column mappings of virtual fields" do
      timestamp = Time.utc
      b = BlogPost.new({
        name:       "AWebVersionOfInTheHillsTheCities",
        version:    5,
        publisher:  "RandomBlogger",
        url:        "www.random-blog.blog",
        created_at: timestamp,
      })
      b.attribute_before_typecast(:created_at).should eq timestamp
    end

    it "returns own attribute" do
      f = Factory.build_facebook_profile(uid: "111", login: "my_login")
      f.attribute_before_typecast("uid").should eq("111")
    end

    it "returns parent attribute" do
      f = Factory.build_facebook_profile(uid: "111", login: "my_login")
      f.attribute_before_typecast("login").should eq("my_login")
    end
  end

  describe "#arguments_to_save" do
    it "returns named tuple with correct keys" do
      r = Factory.build_twitter_profile.arguments_to_save
      r.is_a?(NamedTuple).should be_true
      r.keys.should eq({:args, :fields})
    end

    it "correctly maps column aliases" do
      r = Article.new({
        name:      "ADiscussionOfDagon",
        version:   3,
        publisher: "DiscussionsAndOtherStuff",
        size:      21,
      }).arguments_to_save
      r.is_a?(NamedTuple).should be_true
      r.keys.should eq({:args, :fields})
    end

    it "returns tuple with empty arguments if no field was changed" do
      r = Factory.build_twitter_profile.arguments_to_save
      r[:args].empty?.should be_true
      r[:fields].empty?.should be_true
    end

    it "returns tuple with changed parent argument" do
      c = Factory.build_twitter_profile
      c.login = "some new login"
      r = c.arguments_to_save
      r[:args].should eq(db_array("some new login"))
      r[:fields].should eq(db_array("login"))
    end

    it "returns tuple with changed own argument" do
      c = Factory.build_twitter_profile
      c.email = "some new email"
      r = c.arguments_to_save
      r[:args].should eq(db_array("some new email"))
      r[:fields].should eq(db_array("email"))
    end

    it "returns tuple with mapped and changed parent arguments" do
      b = Book.new({
        name:      "ABigLeatherBoundBook",
        version:   1,
        publisher: "AndRichMahogany",
        pages:     5099,
      })

      b.name = "BigLeatherBoundBooks"
      r = b.arguments_to_save
      r[:args].should eq db_array("BigLeatherBoundBooks")
      r[:fields].should eq db_array("title")
    end

    it "returns tuple with mapped and changed child arguments" do
      a = Article.new({
        name:      "TunasWithBreathingApparatuses",
        version:   4,
        publisher: "LikeToEatLions",
        size:      3,
      })

      a.size = 5
      r = a.arguments_to_save
      r[:args].should eq db_array(5)
      r[:fields].should eq db_array("pages")
    end

    it "uses attributes before typecast" do
      raw_json = %({"asd":1})
      json = JSON.parse(raw_json)
      profile = ProfileWithConverter.new({details: JSON.parse("{}")})
      profile.details = json
      profile.details.should eq(json)
      profile.arguments_to_save[:args].should eq([raw_json])
    end
  end

  describe "#arguments_to_insert" do
    it "returns named tuple with :args and :fields keys" do
      r = Factory.build_twitter_profile.arguments_to_insert
      r.is_a?(NamedTuple).should be_true
      r.keys.should eq({:args, :fields})
    end

    it "returns tuple with all fields" do
      r = Factory.build_twitter_profile.arguments_to_insert
      r[:fields].should match_array(%w(login contact_id type email))
    end

    it "returns tuple with all values" do
      r = Factory.build_twitter_profile.arguments_to_insert
      r[:args].should match_array(db_array("some_login", nil, "TwitterProfile", "some_email@example.com"))
    end

    it "maps columns aliases" do
      r = Article.new({
        name:      "MyNameIsDonnieSmith",
        version:   5,
        publisher: "PTA",
        size:      1,
      }).arguments_to_insert
      r.is_a?(NamedTuple).should be_true
      r.keys.should eq({:args, :fields})

      r[:fields].should match_array(%w(title version publisher type pages))
      expected =
        db_specific(
          mysql: ->{ db_array("MyNameIsDonnieSmith", 5, "PTA", "Article", 1) },
          postgres: ->{ db_array("MyNameIsDonnieSmith", 5, "PTA", Bytes[65, 114, 116, 105, 99, 108, 101], 1) }
        )
      r[:args].should match_array(expected)
    end

    it "uses attributes before typecast" do
      raw_json = %({"asd":1})
      json = JSON.parse(raw_json)
      profile = ProfileWithConverter.new({details: json})
      profile.details.should eq(json)
      profile.arguments_to_insert[:args].should eq(["ProfileWithConverter", raw_json])
    end
  end

  describe "#reload" do
    it "properly reloads fields" do
      p = Factory.create_facebook_profile(uid: "1111")
      p1 = FacebookProfile.all.last!
      p1.uid = "2222"
      p1.save!
      p.reload.uid.should eq("2222")
    end
  end
end
