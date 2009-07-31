require 'yaml'
require 'paper_trail/has_paper_trail'
require 'paper_trail/version'

module PaperTrail
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
  
  # Walk the versions to construct an audit trail of the edits made 
  # over time, and by whom.
  def audit_trail options={}
    options[:attributes_to_ignore] ||= %w(updated_at)
    
    audit_trail = []

    versions_desc = versions_including_current_in_descending_order
    
    versions_desc.each_with_index do |version, index|
      previous_version = versions_desc[index + 1]
      break if previous_version.nil?

      attributes_after = yaml_to_hash(version.object)
      attributes_before = yaml_to_hash(previous_version.object)

      # remove some attributes that we don't need to report
      [attributes_before, attributes_after].each do |hash| 
        hash.reject! { |k,v| k.in? Array(options[:attributes_to_ignore]) }
      end
      
      audit_trail << { 
        :event => previous_version.event,
        :changed_by => transform_whodunnit(previous_version.whodunnit),
        :changed_at => previous_version.created_at,
        :changes => differences(attributes_before, attributes_after)
        }
    end

    audit_trail
  end

  protected
  
  def transform_whodunnit(whodunnit)
    whodunnit
  end

  private

  def set_whodunnit
    @@whodunnit = lambda {
      self.send :current_user rescue nil
    }
  end
  
  def yaml_to_hash(yaml)
    return {} if yaml.nil?
    YAML::load(yaml).to_hash
  end

  # Returns an array of hashes, where each hash specifies the +:attribute+, 
  # value +:before+ the change, and value +:after+ the change.
  def differences(before, after)
    before.diff(after).keys.sort.inject([]) do |diffs, k|
      diff = { :attribute => k, :before => before[k], :after => after[k] }
      diffs << diff; diffs
    end
  end

  def versions_including_current_in_descending_order
    v = self.versions.dup
    v << Version.new(:event => 'update', 
      :object => object_to_string(self), 
      :created_at => self.updated_at)
    v.reverse # newest first
  end
end

ActionController::Base.send :include, PaperTrail
