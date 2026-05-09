# frozen_string_literal: true

RSpec.describe RSpec::Sunspot::Profiles do
  around do |example|
    Dir.mktmpdir("rspec-sunspot-profiles") do |dir|
      described_class.reset!
      described_class.cache_root = dir
      example.run
      described_class.reset!
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

    it "raises when an example references an unknown profile" do
      expect do
        described_class.apply_to(sunspot_profile: :missing)
      end.to raise_error(RSpec::Sunspot::Profiles::Error, "unknown sunspot profile: missing")
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
