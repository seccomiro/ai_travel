FactoryBot.define do
  factory :chat_session do
    association :trip
    status { 'active' }
    context_summary { '' }
  end
end
