module PaperTrail
  class Config
    include Singleton
    attr_accessor :enabled

    def initialize
      @enabled = true
    end
  end
end