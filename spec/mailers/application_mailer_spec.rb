require 'rails_helper'

RSpec.describe ApplicationMailer, type: :mailer do
  it 'inherits from ActionMailer::Base' do
    expect(ApplicationMailer).to be < ActionMailer::Base
  end

  it 'sets default from address' do
    expect(ApplicationMailer.default[:from]).to eq('from@example.com')
  end

  it 'uses mailer layout' do
    expect(ApplicationMailer._layout).to eq('mailer')
  end

  it 'can be instantiated' do
    mailer = ApplicationMailer.new
    expect(mailer).to be_an_instance_of(ApplicationMailer)
  end
end 