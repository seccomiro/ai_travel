FactoryBot.define do
  factory :trip do
    association :user
    sequence(:name) { |n| "Trip #{n}" }
    description { "A wonderful trip to explore new places" }
    start_date { 1.week.from_now.to_date }
    end_date { 2.weeks.from_now.to_date }
    status { "planning" }
    is_public { false }
    trip_data { {} }
    sharing_settings { {} }

    trait :active do
      status { "active" }
    end

    trait :completed do
      status { "completed" }
      start_date { 2.weeks.ago.to_date }
      end_date { 1.week.ago.to_date }
    end

    trait :public do
      is_public { true }
    end

    trait :with_dates do
      start_date { Date.current }
      end_date { Date.current + 5.days }
    end

    trait :no_dates do
      start_date { nil }
      end_date { nil }
    end

    trait :with_trip_data do
      trip_data do
        {
          "destinations" => ["Paris", "London"],
          "budget" => 2000,
          "transportation" => "plane"
        }
      end
    end

    trait :with_sharing_settings do
      sharing_settings do
        {
          "allowed_users" => [],
          "share_level" => "view"
        }
      end
    end
  end
end
