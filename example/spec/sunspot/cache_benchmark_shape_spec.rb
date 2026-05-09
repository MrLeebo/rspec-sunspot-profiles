# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sunspot profile cache benchmark shape" do
  TeachingTaxonomy::EXECUTABLE_BENCHMARK_PROFILES.each_with_index do |profile_name, index|
    it "runs executable benchmark profile #{index + 1}", sunspot_profile: profile_name do
      expect(sunspot_profile_names).to include(profile_name.to_s)
      expect(sunspot_profile_data.fetch("records").size).to eq(TeachingTaxonomy::EXECUTABLE_BENCHMARK_RECORD_COUNT)

      hit_value = sunspot_profile_results.dig(profile_name.to_s, "hit")
      expect(hit_value).to be(false)
    end
  end

  TeachingTaxonomy::STATIC_BENCHMARK_PROFILES.each_with_index do |profile_name, index|
    it "runs cacheable benchmark profile #{index + 1}", sunspot_profile: profile_name do
      expect(sunspot_profile_names).to include(profile_name.to_s)
      expect(sunspot_profile_data.fetch("records").size).to eq(TeachingTaxonomy::STATIC_BENCHMARK_RECORD_COUNT)
      expect(sunspot_profile_data.fetch("search")).to include(
        "fulltext" => "Cacheable benchmark #{index + 1}"
      )

      hit_value = sunspot_profile_results.dig(profile_name.to_s, "hit")
      expect([true, false]).to include(hit_value)
    end
  end
end
