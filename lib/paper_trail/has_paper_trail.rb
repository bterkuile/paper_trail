module PaperTrail

  def self.included(base)
    base.send :extend, ClassMethods
  end


  module ClassMethods
    def has_paper_trail
      send :include, InstanceMethods

      cattr_accessor :paper_trail_active
      self.paper_trail_active = true

      has_many :versions, :as => :item, :order => 'created_at ASC, id ASC'

      after_create  :record_create
      before_update :record_update
      after_destroy :record_destroy
    end

    def paper_trail_off
      self.paper_trail_active = false
    end

    def paper_trail_on
      self.paper_trail_active = true
    end
  end


  module InstanceMethods
    def record_create
      versions.create(:event     => 'create',
                      :whodunnit => PaperTrail.whodunnit) if self.class.paper_trail_active && PaperTrail.enabled?
    end

    def record_update
      if changed? and self.class.paper_trail_active and PaperTrail.enabled?
        versions.build :event     => 'update',
                       :object    => object_to_string(previous_version),
                       :whodunnit => PaperTrail.whodunnit
      end
    end

    def record_destroy
      versions.create(:event     => 'destroy',
                      :object    => object_to_string(previous_version),
                      :whodunnit => PaperTrail.whodunnit) if self.class.paper_trail_active && PaperTrail.enabled?
    end

    # Returns the object at the version that was valid at the given timestamp.
    def version_at timestamp
      # short-circuit if the current state is valid
      return self if self.updated_at < timestamp

      version = versions.first(
        :conditions => ['created_at < ?', timestamp],
        :order => 'created_at DESC')
      version.reify if version
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

    def previous_version
      previous = self.clone
      previous.id = id
      changes.each do |attr, ary|
        previous.send "#{attr}=", ary.first
      end
      previous
    end

    def object_to_string(object)
      object.attributes.to_yaml
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
      if self.new_record?
        v = Version.all(:order => 'created_at desc', :conditions => {:item_id => id, :item_type => self.class.name})
      else
        v = self.versions.dup
      end
      v << Version.new(:event => 'update',
        :object => object_to_string(self),
        :created_at => self.updated_at)
      v.reverse # newest first
    end
  end

end

ActiveRecord::Base.send :include, PaperTrail
