# frozen_string_literal: true

RSpec.describe RSpec::Sunspot::Profiles::Cache do
  around do |example|
    Dir.mktmpdir("rspec-sunspot-profiles") do |dir|
      @cache_root = dir
      example.run
    end
  end

  let(:store) { RSpec::Sunspot::Profiles::CacheStore.new(root: @cache_root) }
  let(:cache) { described_class.new(store: store, env: env) }
  let(:env) { {} }
  let(:profile_name) { "articles" }
  let(:profile_definition) { { fields: %i[title body], boost: 2 } }
  let(:dependencies) { { solr_url: "http://localhost:8983/solr/test", sunspot: { batch_size: 100 } } }

  it "builds the artifact and writes metadata on the first run" do
    result = cache.fetch(
      profile_name: profile_name,
      profile_definition: profile_definition,
      dependencies: dependencies,
      restore: lambda { |_artifact_path, _metadata|
        raise "expected cache miss"
      },
      build: lambda { |artifact_path, payload|
        File.write(artifact_path, "artifact:#{payload.fetch('profile_name')}")
        :built
      }
    )

    expect(result.hit?).to be(false)
    expect(result.value).to eq(:built)
    expect(File.read(store.artifact_path(profile_name: profile_name))).to eq("artifact:articles")

    metadata = JSON.parse(File.read(store.metadata_path(profile_name: profile_name)))
    expect(metadata).to include(
      "profile_name" => profile_name,
      "fingerprint" => result.fingerprint,
      "cache_format_version" => RSpec::Sunspot::Profiles::Fingerprint::CACHE_FORMAT_VERSION
    )
    expect(metadata.fetch("hashed_inputs")).to include(
      "profile_name" => profile_name,
      "dependencies" => {
        "solr_url" => "http://localhost:8983/solr/test",
        "sunspot" => { "batch_size" => 100 }
      }
    )
  end

  it "restores the cached artifact when the fingerprint matches" do
    cache.fetch(
      profile_name: profile_name,
      profile_definition: profile_definition,
      dependencies: dependencies,
      restore: ->(*_) { raise "expected first run to build" },
      build: lambda { |artifact_path, _payload|
        File.write(artifact_path, "cached artifact")
      }
    )

    build_calls = 0

    result = cache.fetch(
      profile_name: profile_name,
      profile_definition: profile_definition,
      dependencies: dependencies,
      restore: lambda { |artifact_path, metadata|
        "#{File.read(artifact_path)}:#{metadata.fetch('fingerprint')}"
      },
      build: lambda { |_artifact_path, _payload|
        build_calls += 1
      }
    )

    expect(result.hit?).to be(true)
    expect(result.value).to start_with("cached artifact:")
    expect(build_calls).to eq(0)
  end

  it "rebuilds when the profile definition changes" do
    first_result = cache.fetch(
      profile_name: profile_name,
      profile_definition: profile_definition,
      dependencies: dependencies,
      restore: ->(*_) { raise "expected first run to build" },
      build: lambda { |artifact_path, _payload|
        File.write(artifact_path, "first artifact")
      }
    )

    second_result = cache.fetch(
      profile_name: profile_name,
      profile_definition: profile_definition.merge(fields: %i[title summary]),
      dependencies: dependencies,
      restore: ->(*_) { raise "expected changed definition to miss cache" },
      build: lambda { |artifact_path, _payload|
        File.write(artifact_path, "second artifact")
        :rebuilt
      }
    )

    expect(second_result.hit?).to be(false)
    expect(second_result.value).to eq(:rebuilt)
    expect(second_result.fingerprint).not_to eq(first_result.fingerprint)
    expect(File.read(store.artifact_path(profile_name: profile_name))).to eq("second artifact")
  end

  it "rebuilds when the cache format version changes" do
    cache.fetch(
      profile_name: profile_name,
      profile_definition: profile_definition,
      dependencies: dependencies,
      restore: ->(*_) { raise "expected first run to build" },
      build: lambda { |artifact_path, _payload|
        File.write(artifact_path, "v1 artifact")
      }
    )

    result = cache.fetch(
      profile_name: profile_name,
      profile_definition: profile_definition,
      dependencies: dependencies,
      cache_format_version: 2,
      restore: ->(*_) { raise "expected version change to miss cache" },
      build: lambda { |artifact_path, _payload|
        File.write(artifact_path, "v2 artifact")
        :rebuilt
      }
    )

    expect(result.hit?).to be(false)
    expect(result.value).to eq(:rebuilt)
    metadata = JSON.parse(File.read(store.metadata_path(profile_name: profile_name)))
    expect(metadata.fetch("cache_format_version")).to eq(2)
  end

  it "rebuilds when manual cache busting is enabled" do
    cache.fetch(
      profile_name: profile_name,
      profile_definition: profile_definition,
      dependencies: dependencies,
      restore: ->(*_) { raise "expected first run to build" },
      build: lambda { |artifact_path, _payload|
        File.write(artifact_path, "warm cache")
      }
    )

    busting_cache = described_class.new(store: store, env: { described_class::BUST_ENV => "1" })

    result = busting_cache.fetch(
      profile_name: profile_name,
      profile_definition: profile_definition,
      dependencies: dependencies,
      restore: ->(*_) { raise "expected cache bust to miss cache" },
      build: lambda { |artifact_path, _payload|
        File.write(artifact_path, "rebuilt after bust")
        :rebuilt
      }
    )

    expect(result.hit?).to be(false)
    expect(result.value).to eq(:rebuilt)
    expect(File.read(store.artifact_path(profile_name: profile_name))).to eq("rebuilt after bust")
  end

  it "skips metadata writes when caching is disabled" do
    disabled_cache = described_class.new(store: store, env: { described_class::DISABLE_ENV => "true" })

    result = disabled_cache.fetch(
      profile_name: profile_name,
      profile_definition: profile_definition,
      dependencies: dependencies,
      restore: ->(*_) { raise "expected cache disable to bypass restore" },
      build: lambda { |artifact_path, _payload|
        File.write(artifact_path, "uncached artifact")
        :built
      }
    )

    expect(result.hit?).to be(false)
    expect(result.metadata).to be_nil
    expect(File).not_to exist(store.metadata_path(profile_name: profile_name))
  end
end
