class TripsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_trip, only: [:show, :edit, :update, :destroy, :update_status, :latest_route, :optimize_route]
  before_action :ensure_owner, only: [:show, :edit, :update, :destroy, :update_status, :latest_route, :optimize_route]

  def index
    @trips = current_user.trips.recent
  end

  def show
    # Trip details view - will include chat interface in Phase 2
  end

  def create
    @trip = current_user.trips.create(
      title: t('trips.default_title', date: l(Date.current, format: :long))
    )

    if @trip.persisted?
      chat_session = @trip.chat_sessions.create!
      chat_session.chat_messages.create!(
        role: 'assistant',
        content: t('chat_sessions.welcome_message')
      )
      redirect_to trip_chat_session_path(@trip, chat_session)
    else
      redirect_to trips_path, alert: t('errors.trip_creation_failed')
    end
  end

  def edit
    # Edit trip form
  end

  def update
    if @trip.update(trip_params)
      redirect_to @trip, notice: t('messages.trip_updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @trip.destroy
    redirect_to trips_path, notice: t('messages.trip_deleted')
  end

  def update_status
    if @trip.update(status: params[:status])
      redirect_to @trip, notice: 'Trip status updated successfully'
    else
      redirect_to @trip, alert: 'Failed to update trip status'
    end
  end

  def latest_route
    render json: @trip.trip_data['latest_route']
  end

  def optimize_route
    segments = params[:segments]
    user_preferences = params[:user_preferences] || {}

    if segments.blank?
      render json: { error: 'No segments provided' }, status: :bad_request
      return
    end

    begin
      optimization_service = RouteOptimizationService.new(@trip)
      optimized_route = optimization_service.calculate_optimized_route(segments, user_preferences)

      render json: {
        success: true,
        route: optimized_route,
        message: "Route optimized successfully with #{optimized_route[:segments].length} segments"
      }
    rescue => e
      Rails.logger.error "Route optimization failed: #{e.message}"
      render json: { error: "Route optimization failed: #{e.message}" }, status: :internal_server_error
    end
  end

  private

  def set_trip
    @trip = Trip.find(params[:id])
  end

  def ensure_owner
    redirect_to trips_path, alert: 'Access denied' unless @trip.user == current_user
  end

  def trip_params
    params.require(:trip).permit(:title, :name, :description, :start_date, :end_date, :status, :public_trip)
  end
end
