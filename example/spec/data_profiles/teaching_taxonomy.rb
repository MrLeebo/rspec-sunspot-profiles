# frozen_string_literal: true

module TeachingTaxonomy
  TEACHING_RECORD_COUNT = 3_000
end

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
  }
)

large_records = Array.new(TeachingTaxonomy::TEACHING_RECORD_COUNT) do |index|
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
  }
)
