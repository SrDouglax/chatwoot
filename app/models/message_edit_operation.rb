class MessageEditOperation < ApplicationRecord
  belongs_to :message
  belongs_to :editor, class_name: 'User'

  enum status: { pending: 0, synced: 1, failed: 2 }

  validates :uuid, presence: true, uniqueness: true
  validates :previous_content, :new_content, presence: true
end
