# frozen_string_literal: true

class AddConversationStatusesSimplifiedToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :conversation_statuses_simplified, :boolean, default: false, null: false
  end
end
