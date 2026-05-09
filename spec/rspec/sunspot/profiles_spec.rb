# frozen_string_literal: true

RSpec.describe RSpec::Sunspot::Profiles do
  around do |example|
    Dir.mktmpdir("rspec-sunspot-profiles") do |dir|
      RSpec::Sunspot::Profiles.reset!
      RSpec::Sunspot::Profiles.configure { |c| c.cache_root = dir }
      example.run
      RSpec::Sunspot::Profiles.reset!
    end
  end

  describe ".apply_to" do
    it "adds registered profile data into example metadata" do
      described_class.define(
        :articles,
        data: {
          records: [{ id: 1, title: "First article" }],
          settings: { commit: true }
        }
      )

      metadata = { sunspot_profile: :articles }

      described_class.apply_to(metadata)

      expect(metadata[:sunspot_profile_names]).to eq(["articles"])
      expect(metadata[:sunspot_profile_data]).to eq(
        "records" => [{ "id" => 1, "title" => "First article" }],
        "settings" => { "commit" => true }
      )
      expect(metadata[:sunspot_profile_results]).to include(
        "articles" => include(
          "hit" => false,
          "data" => metadata[:sunspot_profile_data]
        )
      )
    end

    it "merges multiple profiles into one metadata payload" do
      described_class.define(:articles, data: { records: [{ id: 1 }], filters: { published: true } })
      described_class.define(:comments, data: { records: [{ id: 2 }], filters: { locale: "en" } })

      metadata = { sunspot_profiles: %i[articles comments] }

      described_class.apply_to(metadata)

      expect(metadata[:sunspot_profile_data]).to eq(
        "records" => [{ "id" => 1 }, { "id" => 2 }],
        "filters" => { "published" => true, "locale" => "en" }
      )
    end

    it "reuses cached profile data on subsequent applications" do
      described_class.define(:articles, data: { records: [{ id: 1 }] })

      first_metadata = { sunspot_profile: :articles }
      second_metadata = { sunspot_profile: :articles }

      described_class.apply_to(first_metadata)
      described_class.apply_to(second_metadata)

      expect(first_metadata.dig(:sunspot_profile_results, "articles", "hit")).to be(false)
      expect(second_metadata.dig(:sunspot_profile_results, "articles", "hit")).to be(true)
      expect(second_metadata[:sunspot_profile_data]).to eq(first_metadata[:sunspot_profile_data])
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
      expect(metadata.dig(:sunspot_profile_results, "minimal", "hit")).to be(false)
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

    it "does not restore executable profiles from the cache" do
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

      expect(first_metadata.dig(:sunspot_profile_results, "minimal", "hit")).to be(false)
      expect(second_metadata.dig(:sunspot_profile_results, "minimal", "hit")).to be(false)
      expect(FactoryBot).to have_received(:create).twice
      expect(second_metadata[:sunspot_profile_data]).to eq(
        "records" => [{ "class" => "Individual", "id" => 11 }]
      )
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
      described_class.define(:articles, data: { records: [{ id: 1 }] })

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
      expect(metadata[:sunspot_profile_data]).to eq("records" => [{ "id" => 1 }])
      expect(example).to have_received(:run)
    end

    it "auto-loads profile files from the configured profiles_path" do
      Dir.mktmpdir("rspec-sunspot-profiles-autoload") do |dir|
        profile_file = File.join(dir, "my_profile.rb")
        File.write(profile_file, "RSpec::Sunspot::Profiles.define(:auto_loaded, data: { records: [{ id: 99 }] })")

        described_class.configure { |c| c.profiles_path = dir }

        config = Object.new
        config.define_singleton_method(:include) { |_mod| nil }
        config.define_singleton_method(:around) { |&_block| nil }

        described_class.install!(config)

        expect(described_class.configuration.profiles["auto_loaded"]).not_to be_nil
      end
    end

    it "skips auto-loading when profiles_path is nil" do
      described_class.configure { |c| c.profiles_path = nil }

      config = Object.new
      config.define_singleton_method(:include) { |_mod| nil }
      config.define_singleton_method(:around) { |&_block| nil }

      expect { described_class.install!(config) }.not_to raise_error
      expect(described_class.configuration.profiles).to be_empty
    end

    it "skips auto-loading when profiles_path directory does not exist" do
      described_class.configure { |c| c.profiles_path = "nonexistent/path/to/profiles" }

      config = Object.new
      config.define_singleton_method(:include) { |_mod| nil }
      config.define_singleton_method(:around) { |&_block| nil }

      expect { described_class.install!(config) }.not_to raise_error
    end
  end

  describe ".configure" do
    it "sets cache_root via the configure block" do
      Dir.mktmpdir("rspec-sunspot-profiles-custom-root") do |dir|
        described_class.configure { |c| c.cache_root = dir }
        expect(described_class.cache_root).to eq(File.expand_path(dir))
      end
    end

    it "sets cache_disabled via the configure block" do
      described_class.configure { |c| c.cache_disabled = true }
      expect(described_class.cache_disabled?).to be(true)
    end

    it "disabling cache via configure prevents writing metadata" do
      described_class.configure { |c| c.cache_disabled = true }
      described_class.define(:articles, data: { records: [{ id: 1 }] })

      first_metadata = { sunspot_profile: :articles }
      second_metadata = { sunspot_profile: :articles }

      described_class.apply_to(first_metadata)
      described_class.apply_to(second_metadata)

      expect(first_metadata.dig(:sunspot_profile_results, "articles", "hit")).to be(false)
      expect(second_metadata.dig(:sunspot_profile_results, "articles", "hit")).to be(false)
    end
  end

  describe RSpec::Sunspot::Profiles::Helpers do
    let(:helper_host) { Class.new { include RSpec::Sunspot::Profiles::Helpers }.new }

    it "exposes the applied profile metadata for the current example" do
      example = instance_double(
        "RSpec example",
        metadata: {
          sunspot_profile_names: ["articles"],
          sunspot_profile_data: { "records" => [{ "id" => 1 }] },
          sunspot_profile_results: { "articles" => { "hit" => true } }
        }
      )

      allow(RSpec).to receive(:current_example).and_return(example)

      expect(helper_host.sunspot_profile_names).to eq(["articles"])
      expect(helper_host.sunspot_profile_data).to eq("records" => [{ "id" => 1 }])
      expect(helper_host.sunspot_profile_results).to eq("articles" => { "hit" => true })
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
