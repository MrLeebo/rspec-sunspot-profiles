# frozen_string_literal: true

RSpec.describe RSpec::Sunspot::Profiles do
  around do |example|
    RSpec::Sunspot::Profiles.reset!
    example.run
    RSpec::Sunspot::Profiles.reset!
  end

  describe ".apply_to" do
    it "adds registered profile data into example metadata" do
      stub_sunspot
      stub_const("Article", Struct.new(:id))

      described_class.define(:articles) do
        Sunspot.index(Article.new(1))
      end

      metadata = { sunspot_profile: :articles }

      described_class.apply_to(metadata)

      expect(metadata[:sunspot_profile_names]).to eq(["articles"])
      expect(metadata[:sunspot_profile_data]).to eq(
        "records" => [{ "class" => "Article", "id" => 1 }]
      )
      expect(metadata[:sunspot_profile_results]).to eq(
        "articles" => {
          "type" => "executable",
          "data" => metadata[:sunspot_profile_data]
        }
      )
    end

    it "merges multiple profiles into one metadata payload" do
      stub_sunspot
      stub_const("Article", Struct.new(:id))
      stub_const("Comment", Struct.new(:id))

      described_class.define(:articles) { Sunspot.index(Article.new(1)) }
      described_class.define(:comments) { Sunspot.index(Comment.new(2)) }

      metadata = { sunspot_profiles: %i[articles comments] }

      described_class.apply_to(metadata)

      expect(metadata[:sunspot_profile_data]).to eq(
        "records" => [{ "class" => "Article", "id" => 1 }, { "class" => "Comment", "id" => 2 }]
      )
    end

    it "runs profiles on subsequent applications" do
      stub_sunspot
      stub_const("Article", Struct.new(:id))
      call_count = 0

      described_class.define(:articles) do
        call_count += 1
        Sunspot.index(Article.new(call_count))
      end

      first_metadata = { sunspot_profile: :articles }
      second_metadata = { sunspot_profile: :articles }

      described_class.apply_to(first_metadata)
      described_class.apply_to(second_metadata)

      expect(first_metadata[:sunspot_profile_data]).to eq(
        "records" => [{ "class" => "Article", "id" => 1 }]
      )
      expect(second_metadata[:sunspot_profile_data]).to eq(
        "records" => [{ "class" => "Article", "id" => 2 }]
      )
      expect(second_metadata.dig(:sunspot_profile_results, "articles", "type")).to eq("executable")
    end

    it "captures records indexed by executable profiles that use FactoryBot directly" do
      stub_sunspot
      stub_const("Individual", Struct.new(:id))
      stub_const("Job", Struct.new(:id))
      stub_const("FactoryBot", Module.new)

      allow(FactoryBot).to receive(:create) do |factory_name, *_traits|
        record = factory_name == :individual ? Individual.new(10) : Job.new(20)
        Sunspot.index(record)
        record
      end

      Object.new.instance_eval do
        profile :minimal do
          FactoryBot.create(:individual, :new_account)
          FactoryBot.create(:job, :listed_today)
        end
      end

      metadata = { sunspot_profile: :minimal }

      described_class.apply_to(metadata)

      expect(metadata[:sunspot_profile_data]).to eq(
        "records" => [
          { "class" => "Individual", "id" => 10 },
          { "class" => "Job", "id" => 20 }
        ]
      )
      expect(metadata.dig(:sunspot_profile_results, "minimal", "type")).to eq("executable")
    end

    it "captures records indexed by executable profiles without any factory helper" do
      stub_sunspot

      stub_const("Individual", Class.new do
        attr_reader :id

        def initialize(id)
          @id = id
        end

        def self.create!
          record = new(10)
          Sunspot.index(record)
          record
        end
      end)

      described_class.profile(:minimal) do
        Individual.create!
      end

      metadata = { sunspot_profile: :minimal }

      described_class.apply_to(metadata)

      expect(metadata[:sunspot_profile_data]).to eq(
        "records" => [{ "class" => "Individual", "id" => 10 }]
      )
    end

    it "runs executable profiles each time they are requested" do
      stub_sunspot
      stub_const("Individual", Struct.new(:id))
      stub_const("FactoryBot", Module.new)

      call_count = 0
      allow(FactoryBot).to receive(:create) do
        call_count += 1
        record = Individual.new(9 + call_count)
        Sunspot.index(record)
        record
      end

      described_class.profile(:minimal) do
        FactoryBot.create(:individual)
      end

      first_metadata = { sunspot_profile: :minimal }
      second_metadata = { sunspot_profile: :minimal }

      described_class.apply_to(first_metadata)
      described_class.apply_to(second_metadata)

      expect(FactoryBot).to have_received(:create).twice
      expect(second_metadata[:sunspot_profile_data]).to eq(
        "records" => [{ "class" => "Individual", "id" => 11 }]
      )
      expect(second_metadata.dig(:sunspot_profile_results, "minimal", "type")).to eq("executable")
    end

    it "runs a shared profile block only once and reuses the result for subsequent applications" do
      stub_sunspot
      stub_const("Article", Struct.new(:id))
      call_count = 0

      described_class.define(:articles, shared: true) do
        call_count += 1
        Sunspot.index(Article.new(call_count))
      end

      first_metadata = { sunspot_profile: :articles }
      second_metadata = { sunspot_profile: :articles }

      described_class.apply_to(first_metadata)
      described_class.apply_to(second_metadata)

      expect(call_count).to eq(1)
      expect(first_metadata[:sunspot_profile_data]).to eq(
        "records" => [{ "class" => "Article", "id" => 1 }]
      )
      expect(second_metadata[:sunspot_profile_data]).to eq(
        "records" => [{ "class" => "Article", "id" => 1 }]
      )
    end

    it "caches shared profile results even when no records are indexed" do
      call_count = 0

      described_class.define(:empty, shared: true) do
        call_count += 1
      end

      described_class.apply_to(sunspot_profile: :empty)
      described_class.apply_to(sunspot_profile: :empty)

      expect(call_count).to eq(1)
    end

    it "does not share cache between shared and non-shared profiles of different names" do
      stub_sunspot
      stub_const("Article", Struct.new(:id))
      stub_const("Comment", Struct.new(:id))
      article_calls = 0
      comment_calls = 0

      described_class.define(:articles, shared: true) do
        article_calls += 1
        Sunspot.index(Article.new(article_calls))
      end

      described_class.define(:comments) do
        comment_calls += 1
        Sunspot.index(Comment.new(comment_calls))
      end

      described_class.apply_to(sunspot_profiles: %i[articles comments])
      described_class.apply_to(sunspot_profiles: %i[articles comments])

      expect(article_calls).to eq(1)
      expect(comment_calls).to eq(2)
    end

    it "raises when an example references an unknown profile" do
      expect do
        described_class.apply_to(sunspot_profile: :missing)
      end.to raise_error(RSpec::Sunspot::Profiles::Error, "unknown sunspot profile: missing")
    end

    it "allows executable profiles to run even when no records are indexed" do
      described_class.profile(:minimal) do
        :no_indexing_happened
      end

      metadata = { sunspot_profile: :minimal }

      described_class.apply_to(metadata)

      expect(metadata[:sunspot_profile_data]).to eq({})
    end
  end

  describe ".install!" do
    it "wires metadata application into an RSpec configuration" do
      stub_sunspot
      stub_const("Article", Struct.new(:id))
      described_class.define(:articles) { Sunspot.index(Article.new(1)) }

      included_module = nil
      around_hook = nil
      config = Object.new

      config.define_singleton_method(:include) do |mod|
        included_module = mod
      end

      config.define_singleton_method(:around) do |&block|
        around_hook = block
      end

      described_class.install!(config)

      metadata = { sunspot_profile: :articles }
      example = instance_double("RSpec example", metadata: metadata, run: true)

      around_hook.call(example)

      expect(included_module).to eq(RSpec::Sunspot::Profiles::Helpers)
      expect(metadata[:sunspot_profile_data]).to eq("records" => [{ "class" => "Article", "id" => 1 }])
      expect(example).to have_received(:run)
    end

    it "auto-loads profile files from the configured profiles_path" do
      Dir.mktmpdir("rspec-sunspot-profiles-autoload") do |dir|
        profile_file = File.join(dir, "my_profile.rb")
        File.write(profile_file, "RSpec::Sunspot::Profiles.define(:auto_loaded) {}\n")

        described_class.configuration.profiles_path = dir

        config = Object.new
        config.define_singleton_method(:include) { |_mod| nil }
        config.define_singleton_method(:around) { |&_block| nil }

        described_class.install!(config)

        expect(described_class.configuration.profiles["auto_loaded"]).not_to be_nil
        expect(described_class.configuration.profiles["auto_loaded"].block).not_to be_nil
      end
    end

    it "skips auto-loading when profiles_path is nil" do
      described_class.configuration.profiles_path = nil

      config = Object.new
      config.define_singleton_method(:include) { |_mod| nil }
      config.define_singleton_method(:around) { |&_block| nil }

      expect { described_class.install!(config) }.not_to raise_error
      expect(described_class.configuration.profiles).to be_empty
    end

    it "skips auto-loading when profiles_path directory does not exist" do
      described_class.configuration.profiles_path = "nonexistent/path/to/profiles"

      config = Object.new
      config.define_singleton_method(:include) { |_mod| nil }
      config.define_singleton_method(:around) { |&_block| nil }

      expect { described_class.install!(config) }.not_to raise_error
    end
  end

  describe ".configure" do
    it "automatically calls install! after the block" do
      allow(described_class).to receive(:install!)
      described_class.configure { |c| c.profiles_path = "spec/data_profiles" }
      expect(described_class).to have_received(:install!)
    end
  end

  describe "duplicate profile registration" do
    it "requires profiles to be defined with a block" do
      expect do
        described_class.define(:articles)
      end.to raise_error(ArgumentError, "profile articles must be defined with a block")
    end

    it "raises when the same profile name is registered twice" do
      described_class.define(:articles) { nil }

      expect do
        described_class.define(:articles) { nil }
      end.to raise_error(RSpec::Sunspot::Profiles::Error, "sunspot profile already registered: articles")
    end

    it "raises when auto-loaded files define the same profile twice" do
      Dir.mktmpdir("rspec-sunspot-profiles-duplicates") do |dir|
        File.write(File.join(dir, "first.rb"), "profile :duplicate do; end\n")
        File.write(File.join(dir, "second.rb"), "profile :duplicate do; end\n")

        described_class.configuration.profiles_path = dir

        config = Object.new
        config.define_singleton_method(:include) { |_mod| nil }
        config.define_singleton_method(:around) { |&_block| nil }

        expect do
          described_class.install!(config)
        end.to raise_error(RSpec::Sunspot::Profiles::Error, "sunspot profile already registered: duplicate")
      end
    end
  end

  describe RSpec::Sunspot::Profiles::Helpers do
    let(:helper_host) { Class.new { include RSpec::Sunspot::Profiles::Helpers }.new }

    it "exposes the applied profile metadata for the current example" do
      example = instance_double(
        "RSpec example",
        metadata: {
          sunspot_profile_names: ["articles"],
          sunspot_profile_data: { "records" => [{ "class" => "Article", "id" => 1 }] },
          sunspot_profile_results: { "articles" => { "type" => "executable" } }
        }
      )

      allow(RSpec).to receive(:current_example).and_return(example)

      expect(helper_host.sunspot_profile_names).to eq(["articles"])
      expect(helper_host.sunspot_profile_data).to eq("records" => [{ "class" => "Article", "id" => 1 }])
      expect(helper_host.sunspot_profile_results).to eq("articles" => { "type" => "executable" })
    end
  end

  def stub_sunspot
    stub_const("Sunspot", Module.new)

    session = Class.new do
      def index(*records)
        records.flatten
      end

      alias index! index
      alias add index
      alias add! index
    end.new

    Sunspot.singleton_class.class_eval do
      define_method(:session) { @session }
      define_method(:session=) { |value| @session = value }
      define_method(:index) { |*records| self.session.index(*records) }
    end

    Sunspot.session = session
  end
end
