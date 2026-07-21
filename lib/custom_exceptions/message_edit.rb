module CustomExceptions::MessageEdit
  class Invalid < CustomExceptions::Base
    def message
      @data[:message]
    end

    def http_status
      :unprocessable_entity
    end
  end

  class Conflict < Invalid
    def http_status
      :conflict
    end
  end
end
