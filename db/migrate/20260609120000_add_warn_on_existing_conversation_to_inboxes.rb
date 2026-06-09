# frozen_string_literal: true

class AddWarnOnExistingConversationToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :warn_on_existing_conversation, :boolean, default: false, null: false
  end
end
