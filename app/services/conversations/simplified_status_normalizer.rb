class Conversations::SimplifiedStatusNormalizer
  def initialize(inbox:)
    @inbox = inbox
  end

  def perform
    inbox.conversations.where(status: %i[pending snoozed]).find_each do |conversation|
      conversation.update!(status: :open, snoozed_until: nil)
    end
  end

  private

  attr_reader :inbox
end
