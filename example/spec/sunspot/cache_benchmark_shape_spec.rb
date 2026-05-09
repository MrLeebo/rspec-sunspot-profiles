# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sunspot profile cache benchmark shape", sunspot_profile: :teaching_catalog do
  40.times do |index|
    it "loads the teaching catalog payload #{index + 1}" do
      expect(sunspot_profile_names).to include("teaching_catalog")
      expect(sunspot_profile_data.fetch("records").size).to eq(TeachingTaxonomy::TEACHING_RECORD_COUNT)
      expect(sunspot_profile_data.fetch("search")).to include(
        "fulltext" => "Sunspot relevance"
      )

      hit_value = sunspot_profile_results.dig("teaching_catalog", "hit")
      expect([true, false]).to include(hit_value)
    end
  end
end
