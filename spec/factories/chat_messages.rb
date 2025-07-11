FactoryBot.define do
  factory :chat_message do
    association :chat_session
    role { 'user' }
    content { 'Hello, I want to plan a trip!' }
    metadata { {} }
  end

  trait :assistant do
    role { 'assistant' }
    content { 'I\'d be happy to help you plan your trip! What kind of trip are you thinking about?' }
  end

  trait :system do
    role { 'system' }
    content { 'You are a helpful travel planning assistant.' }
  end
end
