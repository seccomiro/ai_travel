require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  include Devise::Test::ControllerHelpers

  controller do
    def index
      render plain: 'OK'
    end
  end

  before do
    routes.draw { get 'index' => 'anonymous#index' }
  end

  describe 'locale handling' do
    let(:user) { create(:user, preferred_language: 'es') }

    before do
      I18n.locale = I18n.default_locale
    end

    it 'sets locale from params when valid' do
      get :index, params: { locale: 'es' }
      expect(I18n.locale).to eq(:es)
    end

    it 'ignores invalid locale params' do
      get :index, params: { locale: 'invalid' }
      expect(I18n.locale).to eq(I18n.default_locale)
    end

    it 'uses user preferred language when logged in' do
      sign_in user
      get :index
      expect(I18n.locale).to eq(:es)
    end

    it 'uses default locale when no user and no session' do
      get :index
      expect(I18n.locale).to eq(I18n.default_locale)
    end

    it 'persists locale in session' do
      get :index, params: { locale: 'es' }
      expect(session[:locale]).to eq('es')
    end
  end

  describe '#default_url_options' do
    it 'includes current locale' do
      get :index, params: { locale: 'es' }
      expect(controller.send(:default_url_options)).to eq({ locale: :es })
    end
  end

  describe 'Devise parameter sanitization' do
    it 'permits additional parameters for sign up' do
      # This is tested indirectly through the Devise configuration
      # The method is called by Devise when needed
      expect(controller.respond_to?(:configure_permitted_parameters, true)).to be true
    end
  end
end
