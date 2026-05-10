# rspec-sunspot-profiles

`rspec-sunspot-profiles` helps you keep Sunspot-backed RSpec examples fast, readable, and consistent by moving repeated indexing setup into reusable named profiles.

Use it when:

- many examples need the same indexed records
- search setup is making specs noisy

## Installation

```ruby
# Gemfile
group :test do
  gem "rspec-sunspot-profiles"
end
```

```bash
bundle install
```

## Setup

```ruby
# spec/spec_helper.rb (or rails_helper.rb)
require "support/rspec_sunspot_profiles"
```

```ruby
# spec/support/rspec_sunspot_profiles.rb
require "rspec/sunspot/profiles"

RSpec::Sunspot::Profiles.configure do |config|
  # Directory to auto-load profile files from when configure is called.
  # Valid values: String path, Pathname, or nil.
  # Set to nil to disable auto-loading and require profile files manually.
  # Default: "spec/data_profiles"
  config.profiles_path = "spec/data_profiles"
end
```

## Example suite

The snippets below all belong to the same test suite and use the same Sunspot models and profiles.

### 1) Search models

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  searchable do
    text :title, :body
  end
end
```

```ruby
# app/models/comment.rb
class Comment < ApplicationRecord
  searchable do
    text :body
  end
end
```

### 2) Profile declarations

```ruby
# spec/data_profiles/search_content.rb
profile :minimal do
  Article.create!(title: "Solr basics", body: "Getting started with Sunspot")
end

profile :full do
  Article.create!(title: "Solr basics", body: "Getting started with Sunspot")
  Article.create!(title: "RSpec tips", body: "Testing search behavior")
  Comment.create!(body: "Sunspot is fast for this use case")
end
```

Profiles run as normal Ruby blocks. While they run, the gem captures records indexed through Sunspot and stores them in profile data. Profile results are cached for the suite, so each profile is built once and reused.

### 3) RSpec examples using the same profiles

```ruby
RSpec.describe "Search", sunspot_profile: :minimal do
  it "finds indexed articles" do
    results = Article.search { fulltext "Sunspot" }.results
    expect(results.map(&:title)).to include("Solr basics")
  end
end

RSpec.describe "Search with multiple profiles", sunspot_profiles: %i[minimal full] do
  it "applies both profiles to one example" do
    article_results = Article.search { fulltext "RSpec" }.results
    comment_results = Comment.search { fulltext "Sunspot" }.results

    expect(article_results).not_to be_empty
    expect(comment_results).not_to be_empty
  end
end
```

## Configuration

- `config.profiles_path` controls which directory is auto-loaded for profile files.
- Set `config.profiles_path = nil` to disable auto-loading and require files manually.
- Profile names must be unique; duplicate registration raises `RSpec::Sunspot::Profiles::Error`.

## Development

From the repository root:

```bash
bundle install
bundle exec rubocop
bundle exec rspec
```

## Example Rails app

See [example/README.md](example/README.md) for the included Rails app.

## Publishing

See [CONTRIBUTING.md](CONTRIBUTING.md) for release steps.
