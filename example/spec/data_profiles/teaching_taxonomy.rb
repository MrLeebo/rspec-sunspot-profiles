# frozen_string_literal: true

module TeachingTaxonomy
  TEACHING_RECORD_COUNT = 3_000
  EXECUTABLE_BENCHMARK_PROFILE_COUNT = 24
  EXECUTABLE_BENCHMARK_RECORD_COUNT = 120
  STATIC_BENCHMARK_PROFILE_COUNT = 6
  STATIC_BENCHMARK_RECORD_COUNT = 250

  BenchmarkRecord = Struct.new(:id)

  EXECUTABLE_BENCHMARK_PROFILES = Array.new(EXECUTABLE_BENCHMARK_PROFILE_COUNT) do |index|
    :"benchmark_exec_#{index + 1}"
  end.freeze

  STATIC_BENCHMARK_PROFILES = Array.new(STATIC_BENCHMARK_PROFILE_COUNT) do |index|
    :"benchmark_static_#{index + 1}"
  end.freeze

  BENCHMARK_PROFILES = (EXECUTABLE_BENCHMARK_PROFILES + STATIC_BENCHMARK_PROFILES).freeze
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
  },
  dependencies: {
    sunspot: {
      batch_size: 1_000
    },
    taxonomy: "teaching-catalog"
  }
)

TeachingTaxonomy::EXECUTABLE_BENCHMARK_PROFILES.each_with_index do |profile_name, profile_index|
  profile profile_name, dependencies: { taxonomy: "benchmark-executable-#{profile_index + 1}" } do
    offset = profile_index * TeachingTaxonomy::EXECUTABLE_BENCHMARK_RECORD_COUNT

    TeachingTaxonomy::EXECUTABLE_BENCHMARK_RECORD_COUNT.times do |record_offset|
      Sunspot.index(TeachingTaxonomy::BenchmarkRecord.new(offset + record_offset + 1))
    end
  end
end

TeachingTaxonomy::STATIC_BENCHMARK_PROFILES.each_with_index do |profile_name, profile_index|
  offset = profile_index * TeachingTaxonomy::STATIC_BENCHMARK_RECORD_COUNT
  records = Array.new(TeachingTaxonomy::STATIC_BENCHMARK_RECORD_COUNT) do |record_offset|
    {
      id: offset + record_offset + 1,
      title: "Static benchmark #{profile_index + 1}-#{record_offset + 1}",
      body: "Cacheable benchmark payload #{record_offset + 1}",
      profile: profile_name.to_s
    }
  end

  RSpec::Sunspot::Profiles.define(
    profile_name,
    data: {
      records: records,
      search: {
        fulltext: "Cacheable benchmark #{profile_index + 1}",
        with: { profile: profile_name.to_s }
      }
    },
    dependencies: {
      taxonomy: "benchmark-static-#{profile_index + 1}"
    }
  )
end
