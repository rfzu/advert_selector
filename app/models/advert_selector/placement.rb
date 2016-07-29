module AdvertSelector
  class Placement < ActiveRecord::Base
    attr_accessible :conflicting_placements_array, :name, :comment, :request_delay, :only_once_per_session

    has_many :banners, :inverse_of => :placement

    scope :by_name, lambda {|name| where("LOWER(name) = ?", name.to_s.downcase)}

    def name_sym
      @name_sym ||= name.to_s.downcase.to_sym unless name.blank?
    end


    def conflicting_with?(placement_syms)
      placement_syms = [placement_syms.name_sym] if placement_syms.is_a?(Placement)
      placement_syms = placement_syms.collect{|plac| plac.name_sym} if placement_syms.first.is_a?(Placement)

      !(placement_syms & conflicting_placements).empty?
    end

    def self.conflicting_placements(string)
      string.to_s.split(/[ ,]/).collect{|name| name.strip}.reject{|name| name.blank?}.collect{|name| name.to_sym}.sort_by{|sym| sym.to_s}.uniq
    end

    def conflicting_placements
      @conflicting_placements ||= ([self.name_sym] + Placement.conflicting_placements(conflicting_placements_array))
    end

    def conflicting_placements_array=(string)
      string = string.join(",") if string.is_a?(Array)
      arr = Placement.conflicting_placements( string )
      arr.delete(name_sym)
      self[:conflicting_placements_array] = arr.join(",")
    end

    after_save :after_save_update_conflicting_placements_info
    def after_save_update_conflicting_placements_info
      if conflicting_placements_array_changed?
        saved_org = Placement.conflicting_placements(conflicting_placements_array_change.first)
        saved_new = Placement.conflicting_placements(conflicting_placements_array_change.last)

        (saved_org-saved_new).each do |name|
          if placement = Placement.by_name(name).first
            placement.conflicting_placements_array = placement.conflicting_placements.reject{|var| var == name_sym}
            placement.save if placement.conflicting_placements_array_changed?
          end
        end
        saved_new.each do |name|
          if placement = Placement.where(:name => name).first
            placement.conflicting_placements_array = placement.conflicting_placements.push(name_sym)
            placement.save if placement.conflicting_placements_array_changed?
          end
        end
      end
    end

  end
end
