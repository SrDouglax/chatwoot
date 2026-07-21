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
    validate_editing_enabled!
    validate_editor!
    invalid!('Only recent outgoing text messages can be edited') unless eligible_message?
    invalid!('Message content cannot be blank') if content.blank?
    invalid!('Message content has changed') unless message.content == expected_content
    invalid!('Message content is unchanged') if message.content == content
  end

  def validate_editing_enabled!
    return if message.inbox.api? && message.inbox.channel.message_editing_enabled?

    invalid!('Message editing is disabled for this inbox')
  end

  def validate_editor!
    return if user.is_a?(User) && message.sender == user

    invalid!('Only the original sending agent can edit this message')
  end

  def eligible_message?
    eligible_message_shape? && eligible_message_state? && message.created_at >= EDIT_WINDOW.ago
  end

  def eligible_message_shape?
    message.outgoing? && !message.private? && message.text? && message.content.present? && message.attachments.none?
  end

  def eligible_message_state?
    !message.failed? && !message.deleted
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
