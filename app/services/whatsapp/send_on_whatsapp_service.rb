class Whatsapp::SendOnWhatsappService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Whatsapp
  end

  def perform_reply
    should_send_template_message = template_params.present? || !message.conversation.can_reply?
    if should_send_template_message
      send_template_message
    else
      send_session_message
    end
  end

  def send_template_message
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params,
      message: message
    )

    name, namespace, lang_code, processed_parameters = processor.call

    if name.blank?
      message.update!(status: :failed, external_error: 'Template not found or invalid template name')
      return
    end

    message_id = channel.send_template(message.conversation.contact_inbox.source_id, {
                                         name: name,
                                         namespace: namespace,
                                         lang_code: lang_code,
                                         parameters: processed_parameters
                                       }, message)
    message.update!(source_id: message_id) if message_id.present?
  end

  def send_session_message
    message_id = channel.send_message(
      message.conversation.contact_inbox.source_id,
      message,
      outgoing_content: outgoing_content_for_delivery
    )
    message.update!(source_id: message_id) if message_id.present?
  end

  def template_params
    message.additional_attributes && message.additional_attributes['template_params']
  end

  def outgoing_content_for_delivery
    return message.outgoing_content unless should_append_agent_name?

    "*#{agent_name}*:\n#{message.outgoing_content}"
  end

  def should_append_agent_name?
    channel.append_agent_name? &&
      message.sender.is_a?(User) &&
      message.outgoing_content.present? &&
      (message.attachments.present? || message.content_type == 'text')
  end

  def agent_name
    message.sender.available_name.presence || message.sender.name
  end
end
