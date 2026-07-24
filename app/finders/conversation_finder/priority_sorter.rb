class ConversationFinder::PrioritySorter
  def initialize(scope:, params:)
    @scope = scope
    @params = params
  end

  def perform
    return scope unless priority_first?
    return scope if params[:sort_by].to_s.start_with?('priority_')

    scope.sort_on_priority_first
  end

  private

  attr_reader :scope, :params

  def priority_first?
    ActiveModel::Type::Boolean.new.cast(params.fetch(:priority_first, true))
  end
end
