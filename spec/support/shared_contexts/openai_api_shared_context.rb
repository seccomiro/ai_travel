RSpec.shared_context "with OpenAI API stub" do
  before do
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          id: "chatcmpl-123",
          object: "chat.completion",
          created: Time.now.to_i,
          model: "gpt-4o",
          choices: [{
            index: 0,
            message: {
              role: "assistant",
              content: "Hello there! How can I help you plan your trip today?",
            },
            finish_reason: "stop",
          }],
          usage: {
            prompt_tokens: 5,
            completion_tokens: 7,
            total_tokens: 12,
          },
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end
