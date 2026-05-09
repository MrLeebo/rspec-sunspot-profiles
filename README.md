# rspec-sunspot-profiles

`rspec-sunspot-profiles` is a small Ruby gem scaffold for cache-aware Sunspot profile reuse in RSpec suites.

## What it adds

The initial implementation provides:

- deterministic profile fingerprints based on profile inputs instead of timestamps
- an on-disk cache store for profile artifacts and metadata
- a cache coordinator that restores cached artifacts when the fingerprint still matches
- explicit cache invalidation through cache-format versioning and environment variables
- RSpec coverage for cache hits, misses, and invalidation behavior

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
- `spec/spec_helper.rb`
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
cache = RSpec::Sunspot::Profiles.cache(root: "tmp/sunspot-profiles")

result = cache.fetch(
  profile_name: "articles",
  profile_definition: {
    fields: %i[title body],
    filters: { published: true }
  },
  dependencies: {
    solr_url: "http://localhost:8983/solr/test"
  },
  restore: lambda { |artifact_path, _metadata|
    File.read(artifact_path)
  },
  build: lambda { |artifact_path, payload|
    File.write(artifact_path, payload.fetch("profile_name"))
  }
)

result.hit? # true on cache hit, false on rebuild
```

`build` is responsible for writing the artifact file when caching is enabled.

## Invalidation controls

Set either environment variable to control cache behavior:

- `RSPEC_SUNSPOT_PROFILES_CACHE_DISABLE=1` — bypass cache lookups and metadata writes
- `RSPEC_SUNSPOT_PROFILES_CACHE_BUST=1` — force a rebuild and refresh the stored metadata

You can also pass a different `cache_format_version` to `fetch` when an internal cache schema change should invalidate prior entries.

## Development

Install dependencies and run specs:

```bash
bundle install
bundle exec rspec
```
