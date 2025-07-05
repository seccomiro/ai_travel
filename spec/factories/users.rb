FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    first_name { "John" }
    last_name { "Doe" }
    preferred_language { "en" }
    timezone { "UTC" }

    trait :spanish do
      preferred_language { "es" }
    end

    trait :with_trips do
      after(:create) do |user|
        create_list(:trip, 3, user: user)
      end
    end

    trait :admin do
      # Future admin functionality
    end
  end
end
