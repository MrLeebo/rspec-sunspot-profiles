# rspec-sunspot-profiles

`rspec-sunspot-profiles` lets you define reusable Sunspot data profiles and attach them to RSpec examples through metadata.

## What it adds

The current implementation provides:

- named data profiles for RSpec example metadata
- deterministic profile fingerprints based on profile inputs instead of timestamps
- an on-disk cache store for profile artifacts and metadata
- a cache coordinator that restores cached artifacts when the fingerprint still matches
- explicit cache invalidation through cache-format versioning and environment variables
- helper methods for reading applied profile data inside examples
- RSpec coverage for cache hits, misses, metadata application, and invalidation behavior

## Added files

- `Gemfile`
- `Rakefile`
- `rspec-sunspot-profiles.gemspec`
- `lib/rspec-sunspot-profiles.rb`
- `lib/rspec/sunspot/profiles.rb`
- `lib/rspec/sunspot/profiles/version.rb`
- `lib/rspec/sunspot/profiles/fingerprint.rb`
- `lib/rspec/sunspot/profiles/cache_store.rb`
- `lib/rspec/sunspot/profiles/cache.rb`
- `lib/rspec/sunspot/profiles/configuration.rb`
- `lib/rspec/sunspot/profiles/helpers.rb`
- `spec/spec_helper.rb`
- `spec/rspec/sunspot/profiles_spec.rb`
- `spec/rspec/sunspot/profiles/fingerprint_spec.rb`
- `spec/rspec/sunspot/profiles/cache_spec.rb`

## Cache contract

Each cache entry is keyed by a SHA-256 fingerprint built from:

- the profile name
- the profile definition or DSL-derived configuration
- relevant Sunspot or Solr dependencies
- the gem version
- an internal cache format version

This keeps cache invalidation conservative: if any meaningful input changes, the fingerprint changes too.

## Cache metadata

Each profile cache directory stores:

- `artifact` — the cached profile artifact
- `metadata.json` — metadata containing:
  - `profile_name`
  - `fingerprint`
  - `cache_format_version`
  - `created_at`
  - `hashed_inputs`

The metadata acts like an etag for the next run.

## Usage

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

RSpec.describe "searching", sunspot_profile: :articles do
  it "receives the normalized profile data", :sunspot_profiles => [:articles] do |example|
    example.metadata[:sunspot_profile_data]
    # => { "records" => [...], "search" => { "commit" => true } }

    sunspot_profile_names
    # => ["articles"]

    sunspot_profile_results
    # => { "articles" => { "hit" => true/false, ... } }
  end
end
```

Profile data is normalized into a JSON-safe structure before being cached or exposed to the example.

## Metadata behavior

The gem recognizes two example metadata keys:

- `:sunspot_profile` for a single profile name
- `:sunspot_profiles` for one or more profile names

Before the example runs, the configured profiles are loaded, merged, and written back into example metadata:

- `:sunspot_profile_names` — the normalized ordered profile names
- `:sunspot_profile_data` — the merged profile payload
- `:sunspot_profile_results` — per-profile cache hit/miss details

Helpers with the same names are included into RSpec examples.

## Invalidation controls

Set either environment variable to control cache behavior:

- `RSPEC_SUNSPOT_PROFILES_CACHE_DISABLE=1` — bypass cache lookups and metadata writes
- `RSPEC_SUNSPOT_PROFILES_CACHE_BUST=1` — force a rebuild and refresh the stored metadata

You can also pass a different `cache_format_version` to `fetch` when an internal cache schema change should invalidate prior entries.

## What counts as a cache dependency

Caching is only safe when every meaningful input is part of the fingerprint. For a profile that means:

- the registered profile data
- explicit profile dependencies
- gem version changes
- cache format version changes

Likely invalidators include schema changes, Sunspot or Solr configuration changes, profile data changes, and gem upgrades.

## Development

Install dependencies and run specs:

```bash
bundle install
bundle exec rubocop
bundle exec rspec
```

## Publishing

The repository includes:

- `.github/workflows/ci.yml` for the RSpec suite
- `.github/workflows/rubocop.yml` for linting
- `.github/workflows/publish.yml` for RubyGems releases

The publish workflow is set up for RubyGems trusted publishing and runs on version tags matching `v*` or manual dispatch.
