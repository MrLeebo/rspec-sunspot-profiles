# frozen_string_literal: true

RSpec.describe RSpec::Sunspot::Profiles do
  around do |example|
    Dir.mktmpdir("rspec-sunspot-profiles") do |dir|
      RSpec::Sunspot::Profiles.reset!
      RSpec::Sunspot::Profiles.cache_root = dir
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

    it "supports executable profiles defined with the profile DSL" do
      stub_const("Individual", Struct.new(:id))
      stub_const("Job", Struct.new(:id))
      stub_const("FactoryBot", Module.new)

      created_records = [Individual.new(10), Job.new(20)]
      allow(FactoryBot).to receive(:create) { created_records.shift }

      Object.new.instance_eval do
        profile :minimal do
          FactoryBot :individual, :new_account
          FactoryBot :job, :listed_today
          data search: { commit: true }
        end
      end

      metadata = { sunspot_profile: :minimal }

      described_class.apply_to(metadata)

      expect(FactoryBot).to have_received(:create).with(:individual, :new_account).once
      expect(FactoryBot).to have_received(:create).with(:job, :listed_today).once
      expect(metadata[:sunspot_profile_data]).to eq(
        "records" => [
          { "class" => "Individual", "id" => 10 },
          { "class" => "Job", "id" => 20 }
        ],
        "search" => { "commit" => true }
      )
      expect(metadata.dig(:sunspot_profile_results, "minimal", "hit")).to be(false)
    end

    it "does not restore executable profiles from the cache" do
      stub_const("Individual", Struct.new(:id))
      stub_const("FactoryBot", Module.new)

      allow(FactoryBot).to receive(:create).and_return(Individual.new(10), Individual.new(11))

      described_class.profile(:minimal) do
        FactoryBot :individual
      end

      first_metadata = { sunspot_profile: :minimal }
      second_metadata = { sunspot_profile: :minimal }

      described_class.apply_to(first_metadata)
      described_class.apply_to(second_metadata)

      expect(first_metadata.dig(:sunspot_profile_results, "minimal", "hit")).to be(false)
      expect(second_metadata.dig(:sunspot_profile_results, "minimal", "hit")).to be(false)
      expect(FactoryBot).to have_received(:create).twice
    end

    it "raises when an example references an unknown profile" do
      expect do
        described_class.apply_to(sunspot_profile: :missing)
      end.to raise_error(RSpec::Sunspot::Profiles::Error, "unknown sunspot profile: missing")
    end

    it "raises when executable profiles use FactoryBot without the gem being loaded" do
      described_class.profile(:minimal) do
        FactoryBot :individual
      end

      expect do
        described_class.apply_to(sunspot_profile: :minimal)
      end.to raise_error(RSpec::Sunspot::Profiles::Error, "FactoryBot is not defined")
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
end
