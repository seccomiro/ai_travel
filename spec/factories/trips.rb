FactoryBot.define do
  factory :trip do
    user { nil }
    title { "MyString" }
    description { "MyText" }
    start_date { "2025-07-05" }
    end_date { "2025-07-05" }
    status { "MyString" }
    trip_data { "" }
    sharing_settings { "" }
  end
end
