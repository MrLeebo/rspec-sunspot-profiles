# frozen_string_literal: true

module TeachingTaxonomy
  TEACHING_RECORD_COUNT = 3_000
end

unless Object.const_defined?(:Sunspot)
  module Sunspot
    class << self
      attr_accessor :session
    end
  end
end

unless Sunspot.session
  Sunspot.session = Class.new do
    def index(*records)
      records.flatten
    end

    alias index! index
    alias add index
    alias add! index
  end.new
end

RSpec::Sunspot::Profiles.define(:articles) do
  Sunspot.index(
    {
      id: 1,
      title: "First article",
      body: "Intro to Sunspot",
      category: "guides"
    }
  )
end

RSpec::Sunspot::Profiles.define(:comments) do
  Sunspot.index(
    {
      id: 100,
      body: "Great article",
      article_id: 1
    }
  )
end

RSpec::Sunspot::Profiles.define(:teaching_catalog) do
  large_records = Array.new(TeachingTaxonomy::TEACHING_RECORD_COUNT) do |index|
    {
      id: index + 1,
      title: "Guide #{index + 1}",
      body: "Sunspot relevance scoring example #{index + 1}",
      category: index.even? ? "guides" : "tutorials"
    }
  end

  Sunspot.index(large_records)
end
