class ChatSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_trip
  before_action :set_chat_session, only: [:show, :create_message]
  before_action :ensure_trip_owner, only: [:show, :create, :create_message]

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
      result = ChatResponseService.new(@chat_session).call(@message)
      assistant_message = result[:message]
      @trip = result[:trip]  # Use the updated trip object

      Rails.logger.info "Trip data after AI update: #{@trip.trip_data.inspect}"

      respond_to do |format|
        format.turbo_stream do
          Rails.logger.info "Rendering Turbo Stream update for trip sidebar"

          # Generate all the content we need
          message_content = render_to_string(partial: 'chat_messages/message', locals: { message: assistant_message }, formats: [:html])
          form_content = render_to_string(partial: 'chat_sessions/message_form', locals: { chat_session: @chat_session }, formats: [:html])
          sidebar_content = render_to_string(partial: 'trips/sidebar_content', locals: { trip: @trip }, formats: [:html])

          Rails.logger.info "Sidebar content length: #{sidebar_content.length}"
          Rails.logger.info "Sidebar content preview: #{sidebar_content[0..200]}..."

          render turbo_stream: [
            # Remove the typing indicator
            turbo_stream.update('ai-typing', ''),
            # Add the AI response
            turbo_stream.append('chat-messages', message_content),
            # Reset the form
            turbo_stream.update('message-form', form_content),
            # Update trip sidebar
            turbo_stream.update('trip-sidebar', sidebar_content),
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
    @trip = Trip.find(params[:trip_id])
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
