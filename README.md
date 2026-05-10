# rspec-sunspot-profiles

`rspec-sunspot-profiles` is a small helper gem for RSpec suites that exercise Sunspot-backed search behavior. It lets you register named Sunspot data profiles, apply them to examples through metadata, and reuse that setup across specs without burying fixture shape inside each example.

The gem is designed to keep search-oriented specs readable and repeatable:

- define reusable executable setup profiles once
- attach one or more profiles to an example with RSpec metadata
- access the merged profile data from example metadata or helper methods
- run profile setup blocks when a profile needs live indexing side effects

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

Load the gem from `spec_helper.rb`:

```ruby
# spec_helper.rb
require "support/rspec-sunspot-profiles"
```

And configure it in a support file:

```ruby
# spec/support/rspec-sunspot-profiles.rb
require "rspec/sunspot/profiles"

RSpec::Sunspot::Profiles.configure do |config|
  # Directory to auto-load profile files from when configure is called.
  # Set to nil to disable auto-loading and require profile files manually.
  # Default: "spec/data_profiles"
  # config.profiles_path = "spec/data_profiles"
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

Apply a profile in example metadata:

```ruby
RSpec.describe "searching", sunspot_profile: :minimal do
  it "uses the configured profile" do
    search = Book.search { fulltext: "great gatsby" }
    expect(search.results.first.title).to eq("The Great Gatsby")
  end
end
```

You can also attach multiple profiles with `:sunspot_profiles`.

```ruby
it "works like this", sunspot_profiles: ["newyork", "tokyo"] do
  search = Review.search { stars: 5 }
  expect(search.results.count).to eq(50)
end
```

Applied examples expose:

- `sunspot_profile_names` — the ordered list of applied profile names
- `sunspot_profile_data` — the merged payload from all applied profiles
- `sunspot_profile_results` — per-profile metadata including profile type and captured data

## Configuration

Use `RSpec::Sunspot::Profiles.configure` to set project-level options:

```ruby
# spec/support/rspec-sunspot-profiles.rb
require "rspec/sunspot/profiles"

RSpec::Sunspot::Profiles.configure do |config|
  # Directory to auto-load profile files from when configure is called.
  # Set to nil to disable auto-loading and require profile files manually.
  # Default: "spec/data_profiles"
  config.profiles_path = "spec/data_profiles"
end
```

Profile names must be unique. Registering the same name twice raises `RSpec::Sunspot::Profiles::Error` so duplicate auto-loaded files fail fast instead of silently overwriting each other.

## Development

From the repository root:

```bash
bundle install
bundle exec rubocop
bundle exec rspec
```

## Example Rails app

See [example/README.md](example/README.md) for the included Rails application that demonstrates profile usage through a local path dependency.

## Publishing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on publishing releases.
