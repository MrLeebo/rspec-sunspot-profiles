# Example Rails app

This Rails app demonstrates how to use `rspec-sunspot-profiles` through a local path dependency.

## What it covers

- static profiles loaded from `spec/data_profiles`
- executable benchmark profiles that always run
- merged metadata access through `sunspot_profile_names`, `sunspot_profile_data`, and `sunspot_profile_results`
- cache benchmarking against cache-disabled runs

## Run the example suite

From this directory:

```bash
bundle install
bundle exec rspec
```

## Files to look at

- `spec/support/rspec_sunspot_profiles.rb` — gem configuration for the example app
- `spec/data_profiles/teaching_taxonomy.rb` — sample static and executable profiles
- `spec/sunspot/profile_metadata_spec.rb` — metadata usage examples
- `spec/sunspot/cache_benchmark_shape_spec.rb` — cache benchmark workload shape

## Cache troubleshooting

Applied profiles expose cache diagnostics through `sunspot_profile_results`. For example:

```ruby
result = sunspot_profile_results.fetch("articles")
result["hit"]
result["miss_reason"]
result["cache"]
```

You can also inspect a profile outside an example:

```ruby
RSpec::Sunspot::Profiles.cache_status(:articles)
```
