# frozen_string_literal: true

RSpec.describe RSpec::Sunspot::Profiles::Fingerprint do
  describe ".generate" do
    let(:base_definition) do
      {
        fields: %i[title body],
        filters: {
          published: true,
          locale: "en"
        }
      }
    end

    let(:dependencies) do
      {
        solr: {
          url: "http://localhost:8983/solr/test",
          timeout: 2
        },
        sunspot: {
          batch_size: 100
        }
      }
    end

    it "returns the same fingerprint for equivalent ordered input" do
      first = described_class.generate(
        profile_name: "articles",
        profile_definition: base_definition,
        dependencies: dependencies
      )

      second = described_class.generate(
        profile_name: "articles",
        profile_definition: {
          filters: {
            locale: "en",
            published: true
          },
          fields: %i[title body]
        },
        dependencies: {
          sunspot: {
            batch_size: 100
          },
          solr: {
            timeout: 2,
            url: "http://localhost:8983/solr/test"
          }
        }
      )

      expect(first.fingerprint).to eq(second.fingerprint)
      expect(first.payload).to eq(second.payload)
    end

    it "changes when the profile definition changes" do
      baseline = described_class.generate(
        profile_name: "articles",
        profile_definition: base_definition,
        dependencies: dependencies
      )

      changed = described_class.generate(
        profile_name: "articles",
        profile_definition: base_definition.merge(fields: %i[title summary]),
        dependencies: dependencies
      )

      expect(changed.fingerprint).not_to eq(baseline.fingerprint)
    end

    it "changes when the cache format version changes" do
      baseline = described_class.generate(
        profile_name: "articles",
        profile_definition: base_definition,
        dependencies: dependencies,
        cache_format_version: 1
      )

      changed = described_class.generate(
        profile_name: "articles",
        profile_definition: base_definition,
        dependencies: dependencies,
        cache_format_version: 2
      )

      expect(changed.fingerprint).not_to eq(baseline.fingerprint)
    end
  end
end
