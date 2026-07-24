class Conversations::StatusSettingsUpdater
  def initialize(inbox:, attributes:)
    @inbox = inbox
    @attributes = attributes
  end

  def perform
    statuses_were_simplified = inbox.conversation_statuses_simplified?
    inbox.update!(attributes)
    return unless !statuses_were_simplified && inbox.conversation_statuses_simplified?

    Conversations::SimplifiedStatusNormalizer.new(inbox: inbox).perform
  end

  private

  attr_reader :inbox, :attributes
end
