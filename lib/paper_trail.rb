require 'yaml'
require 'paper_trail/config'
require 'paper_trail/has_paper_trail'
require 'paper_trail/version'

module PaperTrail
  @@whodunnit = nil

  def self.config
    @@config ||= PaperTrail::Config.instance
  end

  def self.included(base)
    base.before_filter :set_whodunnit
  end

  def self.enabled=(value)
    PaperTrail.config.enabled = value
  end

  def self.enabled?
    !!PaperTrail.config.enabled
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
