require 'rails_helper'

RSpec.describe ApplicationJob, type: :job do
  it 'inherits from ActiveJob::Base' do
    expect(ApplicationJob).to be < ActiveJob::Base
  end

  it 'has retry configuration commented out' do
    # The retry_on and discard_on configurations are commented out in the actual file
    # This test ensures the class loads without errors
    expect { ApplicationJob.new }.not_to raise_error
  end

  it 'can be instantiated' do
    job = ApplicationJob.new
    expect(job).to be_an_instance_of(ApplicationJob)
  end
end 