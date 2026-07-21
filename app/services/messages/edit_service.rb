class Messages::EditService
  EDIT_WINDOW = 15.minutes

  def initialize(message:, user:, content:, expected_content:)
    @message = message
    @user = user
    @content = content
    @expected_content = expected_content
  end

  def perform
    message.with_lock do
      validate_edit!
      raise_conflict! if message.edit_operations.pending.exists?

      operation = message.edit_operations.create!(
        editor: user,
        previous_content: message.content,
        new_content: content
      )
      message.update!(content: content, additional_attributes: edit_attributes(operation, 'pending'))
      operation
    end
  rescue ActiveRecord::RecordNotUnique
    raise_conflict!
  end

  private

  attr_reader :message, :user, :content, :expected_content

  def validate_edit!
    invalid!('Message editing is disabled for this inbox') unless message.inbox.api? && message.inbox.channel.message_editing_enabled?
    invalid!('Only the original sending agent can edit this message') unless user.is_a?(User) && message.sender == user
    invalid!('Only recent outgoing text messages can be edited') unless eligible_message?
    invalid!('Message content cannot be blank') if content.blank?
    invalid!('Message content has changed') unless message.content == expected_content
    invalid!('Message content is unchanged') if message.content == content
  end

  def eligible_message?
    message.outgoing? && !message.private? && message.text? && message.content.present? && !message.failed? && !message.deleted &&
      message.attachments.none? && message.created_at >= EDIT_WINDOW.ago
  end

  def edit_attributes(operation, status)
    message.additional_attributes.merge(
      'external_edit' => {
        'id' => operation.uuid,
        'status' => status
      }
    )
  end

  def invalid!(error_message)
    raise CustomExceptions::MessageEdit::Invalid.new(message: error_message)
  end

  def raise_conflict!
    raise CustomExceptions::MessageEdit::Conflict.new(message: 'Another edit is already pending for this message')
  end
end
