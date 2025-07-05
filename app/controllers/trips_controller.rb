class TripsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_trip, only: [:show, :edit, :update, :destroy, :update_status]
  before_action :ensure_owner, only: [:show, :edit, :update, :destroy, :update_status]

  def index
    @trips = current_user.trips.recent
  end

  def show
    # Trip details view - will include chat interface in Phase 2
  end

  def new
    @trip = current_user.trips.build
  end

  def create
    @trip = current_user.trips.build(trip_params)
    
    if @trip.save
      redirect_to @trip, notice: t('messages.trip_created')
    else
      render :new, status: :unprocessable_entity
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
      redirect_to @trip, notice: "Trip status updated successfully"
    else
      redirect_to @trip, alert: "Failed to update trip status"
    end
  end

  private

  def set_trip
    @trip = Trip.find(params[:id])
  end

  def ensure_owner
    redirect_to trips_path, alert: "Access denied" unless @trip.user == current_user
  end

  def trip_params
    params.require(:trip).permit(:title, :name, :description, :start_date, :end_date, :status, :is_public)
  end
end
