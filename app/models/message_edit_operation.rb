class MessageEditOperation < ApplicationRecord
  belongs_to :message
  belongs_to :editor, class_name: 'User'

  enum status: { pending: 0, synced: 1, failed: 2 }

  before_validation :ensure_uuid, on: :create

  validates :uuid, presence: true, uniqueness: true
  validates :previous_content, :new_content, presence: true

  private

  def ensure_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
