# Example Rails app

This Rails app demonstrates how to use `rspec-sunspot-profiles` through a local path dependency.

## What it covers

- profiles loaded from `spec/data_profiles`
- merged metadata access through `sunspot_profile_names`, `sunspot_profile_data`, and `sunspot_profile_results`
- a larger teaching catalog setup for search-oriented examples

## Run the example suite

From this directory:

```bash
bundle install
bundle exec rspec
```

## Files to look at

- `spec/support/rspec_sunspot_profiles.rb` — gem configuration for the example app
- `spec/data_profiles/teaching_taxonomy.rb` — sample profiles
- `spec/sunspot/profile_metadata_spec.rb` — metadata usage examples
