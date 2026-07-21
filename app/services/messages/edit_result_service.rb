class Messages::EditResultService
  VALID_STATUSES = %w[synced failed].freeze

  def initialize(message:, operation_id:, status:, error_code: nil)
    @message = message
    @operation_id = operation_id
    @status = status
    @error_code = error_code
  end

  def perform
    invalid!('Invalid edit result status') unless VALID_STATUSES.include?(status)

    message.with_lock do
      operation = message.edit_operations.find_by!(uuid: operation_id)
      next operation if operation.status == status

      conflict! unless operation.pending?

      operation.update!(status: status, error_code: error_code)
      publish_result(operation)
      operation
    end
  rescue ActiveRecord::RecordNotFound
    invalid!('Edit operation could not be found')
  end

  private

  attr_reader :message, :operation_id, :status, :error_code

  def publish_result(operation)
    message.skip_api_inbox_webhook = true
    attributes = message.additional_attributes.merge(
      'external_edit' => {
        'id' => operation.uuid,
        'status' => status,
        'error_code' => error_code
      }.compact
    )
    updates = { additional_attributes: attributes }
    updates[:content] = operation.previous_content if status == 'failed' && message.content == operation.new_content
    message.update!(updates)
  end

  def invalid!(error_message)
    raise CustomExceptions::MessageEdit::Invalid.new(message: error_message)
  end

  def conflict!
    raise CustomExceptions::MessageEdit::Conflict.new(message: 'Edit operation already has a different result')
  end
end
