require_relative 'alert_analysis_base.rb'

class AlertGasOnlyBase < AlertAnalysisBase
  def initialize(school, report_type)
    super(school, report_type)
  end

  def maximum_alert_date
    @school.aggregated_heat_meters.amr_data.end_date
  end

  def needs_electricity_data?
    false
  end

  def self.template_variables
    specific = {'Gas Meters' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  TEMPLATE_VARIABLES = {
    non_heating_only: {
      description: 'Gas at this school is only used for hot water or in the kitchens',
      units:  TrueClass
    },
    kitchen_only: {
      description: 'Gas at this school is only used in the kitchens',
      units:  TrueClass
    },
    hot_water_only: {
      description: 'Gas at this school is only used just for hot water',
      units:  TrueClass
    },
    heating_only: {
      description: 'Gas at this school is only used heating and not for hot water or in the kitchens',
      units:  TrueClass
    }
  }.freeze

  def non_heating_only
    @school.aggregated_heat_meters.non_heating_only?
  end

  def kitchen_only
    @school.aggregated_heat_meters.kitchen_only?
  end

  def hot_water_only
    @school.aggregated_heat_meters.hot_water_only?
  end

  def heating_only
    @school.aggregated_heat_meters.heating_only?
  end
end