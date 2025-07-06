FactoryBot.define do
  factory :chat_session do
    association :trip
    association :user
    status { 'active' }
    context_summary { '' }
  end
end
