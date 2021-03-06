# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'

puts "\n" * 10
pp "Running Test Chart Manager"

school_name = 'Paulton Junior School' # ''
ENV[SchoolFactory::ENV_SCHOOL_DATA_SOURCE] = SchoolFactory::BATH_HACKED_SCHOOL_DATA
$SCHOOL_FACTORY = SchoolFactory.new
school = $SCHOOL_FACTORY.load_school(school_name)
chart_manager = ChartManager.new(school)
charts = chart_manager.run_standard_chart(:group_by_week_electricity)

charts.each do |chart|
  puts chart.inspect
end
# puts "Got #{charts.length} charts"