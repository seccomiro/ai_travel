module TripsHelper
  # Returns the appropriate CSS class for trip status badges
  def trip_status_badge_class(status)
    case status.to_s
    when 'active'
      'success'
    when 'planning'
      'primary'
    when 'completed'
      'secondary'
    else
      'secondary'
    end
  end

  # Returns the appropriate CSS class for visibility badges
  def trip_visibility_badge_class(is_public)
    is_public ? 'info' : 'secondary'
  end

  # Returns the trip duration in days
  def trip_duration_in_days(start_date, end_date)
    return '-' unless start_date && end_date
    
    (end_date - start_date).to_i + 1
  end

  # Returns formatted date range for a trip
  def trip_date_range(start_date, end_date)
    return t('trips.dates_not_set') unless start_date || end_date
    
    if start_date && end_date
      if start_date == end_date
        l(start_date, format: :long)
      else
        "#{l(start_date, format: :short)} - #{l(end_date, format: :short)}"
      end
    elsif start_date
      "#{t('trips.from')} #{l(start_date, format: :short)}"
    else
      "#{t('trips.until')} #{l(end_date, format: :short)}"
    end
  end

  # Returns truncated description with fallback
  def trip_description_summary(description, length: 100)
    return t('trips.no_description') if description.blank?
    
    truncate(description, length: length)
  end

  # Returns formatted trip status with icon
  def trip_status_with_icon(status)
    icon_class = case status.to_s
                 when 'active'
                   'bi-play-circle'
                 when 'planning'
                   'bi-pencil-square'
                 when 'completed'
                   'bi-check-circle'
                 else
                   'bi-circle'
                 end
    
    content_tag(:span, class: 'text-nowrap') do
      content_tag(:i, '', class: icon_class) + ' ' + t("trips.status.#{status}")
    end
  end
end
