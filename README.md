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

Register profiles in your RSpec setup:

```ruby
RSpec::Sunspot::Profiles.configure do |config|
  config.define(
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
end
```

Apply a profile in example metadata:

```ruby
RSpec.describe "searching", sunspot_profile: :articles do
  it "uses the configured profile" do
    expect(sunspot_profile_names).to eq(["articles"])
    expect(sunspot_profile_data["records"].first["title"]).to eq("First article")
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

Profile cache entries are keyed by a deterministic fingerprint built from the profile name, normalized profile data, declared dependencies, the gem version, and an internal cache format version. If those inputs do not change, the gem can restore the cached artifact from disk instead of rebuilding it.

Each cache entry stores:

- `artifact` — the cached profile artifact
- `metadata.json` — cache metadata for the stored fingerprint and inputs

By default, cache data is stored under `tmp/rspec-sunspot-profiles`.

## Cache controls

Use these environment variables to influence cache behavior:

- `RSPEC_SUNSPOT_PROFILES_CACHE_DISABLE=1` — bypass cache reads and writes
- `RSPEC_SUNSPOT_PROFILES_CACHE_BUST=1` — force a rebuild and refresh the stored cache metadata

## Development

From the repository root:

```bash
bundle install
bundle exec rubocop
bundle exec rspec
```

## Publishing

The repository includes GitHub Actions workflows for CI, RuboCop, and RubyGems publishing. Releases are published through the `publish.yml` workflow on version tags matching `v*` or by manual dispatch.
