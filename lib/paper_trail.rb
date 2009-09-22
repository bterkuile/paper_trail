require 'yaml'
require 'paper_trail/has_paper_trail'
require 'paper_trail/version'
mattr_accessor :disabled


module PaperTrail
  mattr_accessor :disabled
  @@whodunnit = nil

  def self.included(base)
    base.before_filter :set_whodunnit
  end

  def self.whodunnit
    @@whodunnit.respond_to?(:call) ? @@whodunnit.call : @@whodunnit
  end

  def self.whodunnit=(value)
    @@whodunnit = value
  end

  private

  def set_whodunnit
    @@whodunnit = lambda {
      self.send :current_user rescue nil
    }
  end
  
end

ActionController::Base.send :include, PaperTrail
