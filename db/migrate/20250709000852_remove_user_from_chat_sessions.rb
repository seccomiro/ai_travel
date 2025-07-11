class RemoveUserFromChatSessions < ActiveRecord::Migration[8.0]
  def change
    remove_reference :chat_sessions, :user, null: false, foreign_key: true
  end
end
