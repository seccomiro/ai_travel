# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AITools::ModifyTripDetailsTool do
  let(:user) { create(:user) }
  let(:trip) { create(:trip, user: user) }
  let(:tool) { described_class.new(trip) }

  describe '#definition' do
    it 'returns the correct function definition' do
      definition = tool.definition

      expect(definition[:type]).to eq('function')
      expect(definition[:function][:name]).to eq('modify_trip_details')
      expect(definition[:function][:description]).to include('Modify trip details')

      properties = definition[:function][:parameters][:properties]
      expect(properties.keys).to include(:title, :description, :start_date, :end_date, :is_public, :trip_data)
    end
  end

  describe '#call' do
    context 'with valid arguments' do
      let(:args) do
        {
          'title' => 'Updated Trip Title',
          'description' => 'Updated trip description',
          'start_date' => '2024-01-15',
          'end_date' => '2024-01-20',
          'is_public' => true,
          'trip_data' => { 'custom_field' => 'value' }
        }
      end

      it 'updates trip details successfully' do
        result = tool.call(args)

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Trip details updated successfully')
        expect(result[:updated_fields]).to include(:title, :description, :start_date, :end_date, :public_trip, :trip_data)
        expect(result[:trip_id]).to eq(trip.id)

        # Verify the trip was actually updated
        trip.reload
        expect(trip.title).to eq('Updated Trip Title')
        expect(trip.description).to eq('Updated trip description')
        expect(trip.start_date).to eq(Date.parse('2024-01-15'))
        expect(trip.end_date).to eq(Date.parse('2024-01-20'))
        expect(trip.public_trip).to be true
        expect(trip.trip_data['custom_field']).to eq('value')
      end
    end

    context 'with partial arguments' do
      let(:args) do
        {
          'title' => 'Only Title Updated',
          'is_public' => false
        }
      end

      it 'updates only provided fields' do
        result = tool.call(args)

        expect(result[:success]).to be true
        expect(result[:updated_fields]).to include(:title, :public_trip)

        trip.reload
        expect(trip.title).to eq('Only Title Updated')
        expect(trip.public_trip).to be false
        # Other fields should remain unchanged
        expect(trip.description).to be_nil
        expect(trip.start_date).to be_nil
        expect(trip.end_date).to be_nil
      end
    end

    context 'with invalid date format' do
      let(:args) do
        {
          'title' => 'Valid Title',
          'start_date' => 'invalid-date'
        }
      end

      it 'handles invalid dates gracefully' do
        result = tool.call(args)

        expect(result[:success]).to be true
        expect(result[:updated_fields]).to include(:title)

        trip.reload
        expect(trip.title).to eq('Valid Title')
        expect(trip.start_date).to be_nil # Invalid date should not be set
      end
    end

    context 'with trip_data' do
      let(:args) do
        {
          'trip_data' => {
            'new_field' => 'new_value',
            'nested' => { 'key' => 'value' }
          }
        }
      end

      it 'merges trip_data with existing data' do
        # Set existing trip_data
        trip.update(trip_data: { 'existing_field' => 'existing_value' })

        result = tool.call(args)

        expect(result[:success]).to be true

        trip.reload
        expect(trip.trip_data['existing_field']).to eq('existing_value')
        expect(trip.trip_data['new_field']).to eq('new_value')
        expect(trip.trip_data['nested']['key']).to eq('value')
      end
    end

    context 'when trip update fails' do
      let(:args) do
        {
          'title' => '' # Empty title might cause validation error
        }
      end

      it 'returns error information' do
        # Mock the trip to fail validation
        allow(trip).to receive(:update).and_return(false)
        allow(trip).to receive(:errors).and_return(double(full_messages: ['Title cannot be blank']))

        result = tool.call(args)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Failed to update trip details')
        expect(result[:validation_errors]).to include('Title cannot be blank')
      end
    end
  end
end