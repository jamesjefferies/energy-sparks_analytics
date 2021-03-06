#======================== Holiday Alert =======================================
require_relative 'alert_analysis_base.rb'

class AlertImpendingHoliday < AlertAnalysisBase
  WEEKDAYS_HOLIDAY_LOOKAHEAD_PERIOD = 5

  def initialize(school)
    super(school, :impendingholiday)
  end

  def analyse_private(asof_date)
    @analysis_report.add_book_mark_to_base_url('UpcomingHoliday')
    @analysis_report.term = :shortterm

    if !@school.holidays.holiday?(asof_date) && upcoming_holiday?(asof_date, WEEKDAYS_HOLIDAY_LOOKAHEAD_PERIOD)
      @analysis_report.summary = 'There is an upcoming holiday - please turn heating, hot water and appliances off'
      text = 'There is a holiday coming up '
      text += 'please ensure all unnecessary appliances are switched off, '
      text += 'including heating and hot water (but remember to flush when turned back on)'
      @analysis_report.rating = 2.0
      @analysis_report.status = :poor
    else
      @analysis_report.summary = 'There is no upcoming holiday, no action needs to be taken'
      text = ''
      @analysis_report.rating = 10.0
      @analysis_report.status = :good
    end

    description1 = AlertDescriptionDetail.new(:text, text)
    @analysis_report.add_detail(description1)
  end

  def upcoming_holiday?(asof_date, num_days)
    asof_date += 1
    while num_days > 0
      unless asof_date.saturday? || asof_date.sunday?
        num_days -= 1
        return true if @school.holidays.holiday?(asof_date)
      end
      asof_date += 1
    end
    false
  end

  def maximum_alert_date
    @school.holidays.last.start_date
  end
end