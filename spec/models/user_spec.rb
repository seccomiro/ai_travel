require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'is invalid without email' do
      user = build(:user, email: nil)
      expect(user).to_not be_valid
    end

    it 'is invalid without password' do
      user = build(:user, password: nil)
      expect(user).to_not be_valid
    end

    it 'is invalid without first_name' do
      user = build(:user, first_name: nil)
      expect(user).to_not be_valid
    end

    it 'is invalid without last_name' do
      user = build(:user, last_name: nil)
      expect(user).to_not be_valid
    end

    it 'is invalid with duplicate email' do
      create(:user, email: 'test@example.com')
      user = build(:user, email: 'test@example.com')
      expect(user).to_not be_valid
    end

    it 'is invalid with short password' do
      user = build(:user, password: '12345')
      expect(user).to_not be_valid
    end

    it 'validates preferred_language inclusion' do
      user = build(:user, preferred_language: 'fr')
      expect(user).to_not be_valid
    end
  end

  describe 'associations' do
    it 'has many trips' do
      association = described_class.reflect_on_association(:trips)
      expect(association.macro).to eq :has_many
    end

    it 'destroys associated trips when user is destroyed' do
      user = create(:user)
      trip = create(:trip, user: user)

      expect { user.destroy }.to change(Trip, :count).by(-1)
    end
  end

  describe 'instance methods' do
    let(:user) { create(:user, first_name: 'John', last_name: 'Doe') }

    describe '#full_name' do
      it 'returns the full name' do
        expect(user.full_name).to eq('John Doe')
      end
    end

    describe '#display_name' do
      it 'returns the full name when both names are present' do
        expect(user.display_name).to eq('John Doe')
      end

      it 'returns first name when last name is blank' do
        user.last_name = nil
        expect(user.display_name).to eq('John')
      end

      it 'returns email when names are blank' do
        user.first_name = nil
        user.last_name = nil
        expect(user.display_name).to eq(user.email)
      end
    end

    describe '#initials' do
      it 'returns the initials' do
        expect(user.initials).to eq('JD')
      end

      it 'returns first letter of email when names are blank' do
        user.first_name = nil
        user.last_name = nil
        expect(user.initials).to eq(user.email[0].upcase)
      end
    end
  end

  describe 'default values' do
    it 'sets default preferred_language to en' do
      user = User.new(
        email: 'test@example.com',
        password: 'password123',
        first_name: 'John',
        last_name: 'Doe'
      )
      user.save
      expect(user.preferred_language).to eq('en')
    end
  end
end
