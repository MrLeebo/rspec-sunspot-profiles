# frozen_string_literal: true

RSpec::Sunspot::Profiles.define(
  :articles,
  data: {
    records: [
      { id: 1, title: "First article", body: "Intro to Sunspot", category: "guides" }
    ],
    search: {
      fulltext: "Sunspot",
      with: { category: "guides" }
    }
  },
  dependencies: {
    taxonomy: "articles"
  }
)

RSpec::Sunspot::Profiles.define(
  :comments,
  data: {
    records: [
      { id: 100, body: "Great article", article_id: 1 }
    ],
    search: {
      with: { article_id: 1 }
    }
  },
  dependencies: {
    taxonomy: "comments"
  }
)

large_records = Array.new(1_500) do |index|
  {
    id: index + 1,
    title: "Guide #{index + 1}",
    body: "Sunspot relevance scoring example #{index + 1}",
    category: index.even? ? "guides" : "tutorials"
  }
end

RSpec::Sunspot::Profiles.define(
  :teaching_catalog,
  data: {
    records: large_records,
    facets: {
      category: %w[guides tutorials]
    },
    search: {
      fulltext: "Sunspot relevance",
      facet: :category
    }
  },
  dependencies: {
    sunspot: {
      batch_size: 500
    },
    taxonomy: "teaching-catalog"
  }
)
