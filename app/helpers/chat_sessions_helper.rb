module ChatSessionsHelper
  def message_role_class(message)
    case message.role
    when 'user'
      'user-message'
    when 'assistant'
      'assistant-message'
    when 'system'
      'system-message'
    else
      'unknown-message'
    end
  end

  def message_bubble_class(message)
    case message.role
    when 'user'
      'bg-primary text-white'
    when 'assistant'
      'bg-light'
    when 'system'
      'bg-warning'
    else
      'bg-secondary'
    end
  end

  def message_icon_class(message)
    case message.role
    when 'user'
      'bi-person'
    when 'assistant'
      'bi-robot'
    when 'system'
      'bi-gear'
    else
      'bi-question'
    end
  end

  def message_sender_name(message)
    case message.role
    when 'user'
      'You'
    when 'assistant'
      'Tripyo AI'
    when 'system'
      'System'
    else
      'Unknown'
    end
  end

  def format_message_time(message)
    return '' if message.created_at.nil?
    
    message.created_at.strftime('%H:%M')
  end

  def message_metadata_display(message)
    return '' if message.metadata.blank?
    
    # Display tool calls if present
    if message.has_tool_calls?
      tool_names = message.ai_tool_calls.map { |call| call['name'] }.join(', ')
      "Used tools: #{tool_names}"
    elsif message.has_tool_results?
      "Tool results available"
    else
      ''
    end
  end

  def chat_session_status_badge(chat_session)
    case chat_session.status
    when 'active'
      content_tag(:span, 'Active', class: 'badge bg-success')
    when 'completed'
      content_tag(:span, 'Completed', class: 'badge bg-secondary')
    when 'archived'
      content_tag(:span, 'Archived', class: 'badge bg-dark')
    else
      content_tag(:span, 'Unknown', class: 'badge bg-warning')
    end
  end

  def message_count_display(chat_session)
    count = chat_session.message_count
    case count
    when 0
      'No messages'
    when 1
      '1 message'
    else
      "#{count} messages"
    end
  end

  def last_activity_display(chat_session)
    last_message = chat_session.last_message
    return 'Never' if last_message.nil?
    
    time_diff = Time.current - last_message.created_at
    
    case time_diff
    when 0..1.minute
      'Just now'
    when 1.minute..1.hour
      minutes = (time_diff / 1.minute).to_i
      "#{minutes} minute#{'s' if minutes != 1} ago"
    when 1.hour..1.day
      hours = (time_diff / 1.hour).to_i
      "#{hours} hour#{'s' if hours != 1} ago"
    when 1.day..1.week
      days = (time_diff / 1.day).to_i
      "#{days} day#{'s' if days != 1} ago"
    else
      last_message.created_at.strftime('%b %d, %Y')
    end
  end

  def chat_session_summary(chat_session)
    return 'New conversation' if chat_session.message_count == 0
    
    # Try to get a meaningful summary from the first user message
    first_user_message = chat_session.user_messages.order(:created_at).first
    return 'New conversation' if first_user_message.nil?
    
    content = first_user_message.content
    return content if content.length <= 100
    
    # Truncate and add ellipsis
    content[0..96] + '...'
  end

  def typing_indicator_html
    content_tag(:div, class: 'typing-indicator d-flex align-items-center text-muted') do
      content_tag(:span, 'Tripyo AI is typing...', class: 'me-2') +
      content_tag(:div, class: 'typing-dots') do
        content_tag(:span, '', class: 'dot') +
        content_tag(:span, '', class: 'dot') +
        content_tag(:span, '', class: 'dot')
      end
    end
  end

  def message_form_placeholder(chat_session)
    if chat_session.message_count == 0
      'Tell me about your trip plans...'
    else
      'Ask about destinations, accommodations, or activities...'
    end
  end
end
