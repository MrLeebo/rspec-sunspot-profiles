# Example Rails app and cache benchmarking

This repository includes an `example/` Rails application that demonstrates a Sunspot profile taxonomy (`articles`, `comments`, and a larger teaching catalog profile) using this gem via a local path dependency.

The main gem suite includes an integration spec that:

- installs and runs the example app spec suite
- runs a benchmark-focused spec made of many medium profiles (primarily executable profiles)
- benchmarks cache-enabled throughput with a cold cache
- benchmarks cache-enabled throughput with a hot cache
- benchmarks cache-disabled throughput
- asserts that cache-enabled throughput is measurably higher than cache-disabled throughput

If your CI environment is unusually noisy, you can tune the expected speedup thresholds:

- `RSPEC_SUNSPOT_PROFILES_HOT_MULTIPLIER` (default: `0.93`)
- `RSPEC_SUNSPOT_PROFILES_COLD_MULTIPLIER` (default: `1.0`)
- `RSPEC_SUNSPOT_PROFILES_BENCHMARK_SECONDS` (default: `60`)

You can also run the example suite directly:

```bash
cd example
bundle install
bundle exec rspec
```
