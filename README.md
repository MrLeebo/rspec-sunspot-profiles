# rspec-sunspot-profiles

`rspec-sunspot-profiles` is a small helper gem for RSpec suites that exercise Sunspot-backed search behavior. It lets you register named Sunspot data profiles, apply them to examples through metadata, and reuse cached profile artifacts across runs when the underlying inputs have not changed.

The gem is designed to keep search-oriented specs readable and repeatable:

- define reusable profile payloads once
- attach one or more profiles to an example with RSpec metadata
- access the merged profile data from example metadata or helper methods
- avoid rebuilding the same profile data when a deterministic cache fingerprint still matches

## Installation

Add the gem to your test dependencies:

```ruby
group :test do
  gem "rspec-sunspot-profiles"
end
```

Then install dependencies:

```bash
bundle install
```

## Usage

Load the gem and call `configure` from your RSpec configuration. By default, profile files are automatically loaded from `spec/data_profiles/`:

```ruby
# spec_helper.rb
require "rspec/sunspot/profiles"

RSpec::Sunspot::Profiles.configure do |config|
  # config.profiles_path = "spec/search_fixtures"  # custom path
  # config.profiles_path = nil                     # disable auto-loading
end
```

Define an executable profile with ordinary setup code:

```ruby
# spec/data_profiles/minimal.rb

profile :minimal do
  FactoryBot.create(:individual, :new_account)
  FactoryBot.create(:job, :listed_today)
end
```

Executable profiles run the block as-is. The gem watches Sunspot indexing activity during that run and records the indexed model references under `records`, so any setup strategy works as long as it results in documents being indexed.

That means direct model creation works too:

```ruby
profile :minimal do
  Individual.create!
  Job.create!
end
```

Static payload profiles are still supported when you want deterministic cached artifacts instead of executable setup:

```ruby
RSpec::Sunspot::Profiles.define(
  :articles,
  data: {
    records: [
      { id: 1, title: "First article" }
    ],
    search: {
      commit: true
    }
  },
  dependencies: {
    solr_url: "http://localhost:8983/solr/test"
  }
)
```

Apply a profile in example metadata:

```ruby
RSpec.describe "searching", sunspot_profile: :minimal do
  it "uses the configured profile" do
    expect(sunspot_profile_names).to eq(["minimal"])
    expect(sunspot_profile_data["records"]).to include(
      include("class" => "Individual")
    )
  end
end
```

You can also attach multiple profiles with `:sunspot_profiles`. Before the example runs, the gem loads the requested profiles, merges their normalized payloads, and writes the result back into example metadata.

## Metadata and helpers

The gem recognizes these metadata keys:

- `:sunspot_profile` for a single profile name
- `:sunspot_profiles` for one or more profile names

It also exposes the processed values through both example metadata and helper methods:

- `:sunspot_profile_names` / `sunspot_profile_names`
- `:sunspot_profile_data` / `sunspot_profile_data`
- `:sunspot_profile_results` / `sunspot_profile_results`

## Caching

Static profile cache entries are keyed by a deterministic fingerprint built from the profile name, normalized profile data, declared dependencies, the gem version, and an internal cache format version. If those inputs do not change, the gem can restore the cached artifact from disk instead of rebuilding it.

Executable block-based profiles always run when requested so their setup side effects happen for the current example and the captured indexed records reflect that run.

Each cache entry stores:

- `artifact` — the cached profile artifact
- `metadata.json` — cache metadata for the stored fingerprint and inputs

By default, cache data is stored under `tmp/rspec-sunspot-profiles` (configurable via `config.cache_root`).

## Configuration

Use `RSpec::Sunspot::Profiles.configure` to set project-level options:

```ruby
RSpec::Sunspot::Profiles.configure do |config|
  # Directory to auto-load profile files from when configure is called.
  # Set to nil to disable auto-loading and require profile files manually.
  # Default: "spec/data_profiles"
  config.profiles_path = "spec/data_profiles"

  # Directory where static profile cache artifacts are stored.
  # Default: "tmp/rspec-sunspot-profiles"
  config.cache_root = "tmp/rspec-sunspot-profiles"

  # Set to true to hard-disable caching for all profiles.
  # The RSPEC_SUNSPOT_PROFILES_CACHE_DISABLE environment variable also works as a per-run override.
  # Default: false
  config.cache_disabled = false

  # RSpec metadata keys used to attach profiles to examples (rarely need changing).
  config.metadata_key = :sunspot_profile
  config.metadata_collection_key = :sunspot_profiles
  config.data_key = :sunspot_profile_data
  config.results_key = :sunspot_profile_results
  config.names_key = :sunspot_profile_names
end
```

## Cache controls

Use these environment variables for one-off, per-run overrides:

- `RSPEC_SUNSPOT_PROFILES_CACHE_DISABLE=1` — bypass cache reads and writes for this run
- `RSPEC_SUNSPOT_PROFILES_CACHE_BUST=1` — force a rebuild and refresh the stored cache metadata

For a stable project-level setting (e.g., always disabled in CI), prefer `config.cache_disabled = true` in the configure block instead.

## Development

From the repository root:

```bash
bundle install
bundle exec rubocop
bundle exec rspec
```

## Publishing

The repository includes GitHub Actions workflows for CI, RuboCop, and RubyGems publishing. Releases are published through the `publish.yml` workflow on version tags matching `v*` or by manual dispatch.
