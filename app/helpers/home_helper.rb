module HomeHelper
  # Returns a welcome message based on time of day
  def welcome_message_for_time
    hour = Time.current.hour
    case hour
    when 5..11
      t('home.good_morning')
    when 12..17
      t('home.good_afternoon')
    when 18..21
      t('home.good_evening')
    else
      t('home.good_night')
    end
  end

  # Returns the user's greeting with their name
  def user_greeting(user)
    return t('home.welcome_guest') unless user

    "#{welcome_message_for_time}, #{user.display_name}!"
  end

  # Returns feature highlight cards for the home page
  def feature_highlights
    [
      {
        icon: 'bi-chat-dots',
        title: t('home.features.ai_planning.title'),
        description: t('home.features.ai_planning.description')
      },
      {
        icon: 'bi-map',
        title: t('home.features.interactive_maps.title'),
        description: t('home.features.interactive_maps.description')
      },
      {
        icon: 'bi-people',
        title: t('home.features.collaboration.title'),
        description: t('home.features.collaboration.description')
      },
      {
        icon: 'bi-download',
        title: t('home.features.export.title'),
        description: t('home.features.export.description')
      }
    ]
  end

  # Returns stats for the home page
  def platform_stats
    {
      total_trips: Trip.count,
      active_trips: Trip.active.count,
      total_users: User.count,
      this_month_trips: Trip.where('created_at >= ?', 1.month.ago).count
    }
  end

  # Returns recent public trips for showcase
  def recent_public_trips(limit = 3)
    Trip.public_trips.recent.limit(limit)
  end
end
