class Conversations::AssignmentService
  def initialize(conversation:, assignee_id:, assignee_type: nil)
    @conversation = conversation
    @assignee_id = assignee_id
    @assignee_type = assignee_type
  end

  def perform
    agent_bot_assignment? ? assign_agent_bot : assign_agent
  end

  private

  attr_reader :conversation, :assignee_id, :assignee_type

  def assign_agent
    return clear_assignee if assignee_id.blank?
    return unless assignee

    conversation.with_lock do
      if conversation.assignee_agent_bot_id.present? && conversation.pending?
        conversation.status = :open
        conversation.waiting_since = Time.current if conversation.waiting_since.blank?
      end
      conversation.assignee = assignee
      conversation.assignee_agent_bot = nil
      conversation.save!
    end
    assignee
  end

  def clear_assignee
    conversation.assignee = nil
    conversation.assignee_agent_bot = nil
    conversation.save!
  end

  def assign_agent_bot
    return unless agent_bot

    conversation.with_lock do
      conversation.assignee = nil
      conversation.assignee_agent_bot = agent_bot
      conversation.save!
    end
    agent_bot
  end

  def assignee
    @assignee ||= conversation.inbox.assignable_agents.find_by(id: assignee_id)
  end

  def agent_bot
    @agent_bot ||= AgentBot.accessible_to(conversation.account).find_by(id: assignee_id)
  end

  def agent_bot_assignment?
    assignee_type.to_s == 'AgentBot'
  end
end
