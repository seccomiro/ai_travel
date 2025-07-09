class ChatSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_trip
  before_action :set_chat_session, only: [:show, :create_message]
  before_action :ensure_trip_owner, only: [:show, :create_message]

  def show
    # Show the chat interface for the trip
  end

  def create
    @chat_session = @trip.chat_sessions.create!
    redirect_to trip_chat_session_path(@trip, @chat_session)
  rescue => e
    Rails.logger.error("Failed to create chat session: #{e.message}")
    redirect_to @trip, alert: t('chat_sessions.create_error')
  end

  def create_message
    @message = @chat_session.chat_messages.build(
      role: 'user',
      content: params[:content]
    )

    if @message.save
      # Process with AI and create assistant response
      assistant_message = ChatResponseService.new(@chat_session).call(@message)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            # Remove the typing indicator
            turbo_stream.update('ai-typing', ''),
            # Add the AI response
            turbo_stream.append('chat-messages', partial: 'chat_messages/message', locals: { message: assistant_message }),
            # Reset the form
            turbo_stream.update('message-form', partial: 'chat_sessions/message_form', locals: { chat_session: @chat_session }),
            # Update trip sidebar
            turbo_stream.update('trip-sidebar', partial: 'trips/sidebar_content', locals: { trip: @trip }),
          ]
        end
        format.html { redirect_to trip_chat_session_path(@trip, @chat_session) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            # Remove typing indicator
            turbo_stream.update('ai-typing', ''),
            # Show error in form
            turbo_stream.update('message-form',
              partial: 'chat_sessions/message_form',
              locals: { chat_session: @chat_session, error: @message.errors.full_messages.join(', ') }),
          ]
        end
        format.html { redirect_to trip_chat_session_path(@trip, @chat_session), alert: @message.errors.full_messages.join(', ') }
      end
    end
  end

  private

  def set_trip
    @trip = current_user.trips.find(params[:trip_id])
  end

  def set_chat_session
    @chat_session = @trip.chat_sessions.find(params[:id])
  end

  def ensure_trip_owner
    unless @trip.user == current_user
      redirect_to trips_path, alert: t('trips.access_denied')
    end
  end
end
