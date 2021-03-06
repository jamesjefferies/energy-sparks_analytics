# school: defines a school
#         currently derives from Building
#           - TODO(PH,JJ,3Jun18) - at some point decide whether
#           - this is the correct model
#
# JJ - this will ultimately just be an ActiveModel/ActiveRecord School
require_relative '../../../lib/dashboard.rb'

module Dashboard
  class School
    # Energy Sparks existing activerecord fields:
    attr_reader :name, :address, :floor_area, :number_of_pupils
    attr_reader :calendar_id, :competition_role, :created_at, :electricity_dataset, :enrolled
    attr_reader :gas_dataset, :id, :level, :sash_id, :postcode, :school_type, :slug, :update_at
    attr_reader :website, :area_name
    attr_accessor :urn

    def initialize(name, address = nil, floor_area = nil, number_of_pupils = nil, school_type = nil, area_name = 'Bath', urn = nil, postcode = nil)
      @school_type = school_type
      @name = name
      @address = address
      @floor_area = floor_area
      @number_of_pupils = number_of_pupils
      @school_type = school_type
      @area_name = area_name
      @urn = urn
      @postcode = postcode
    end
  end
end