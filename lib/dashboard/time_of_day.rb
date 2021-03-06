# time of day (differentiates between 00:00 and 24:00)
class TimeOfDay
  include Comparable

  attr_reader :hour, :minutes, :relative_time

  def initialize(hour, minutes)
    if hour.nil? || minutes.nil? || hour < 0 || hour > 24 || minutes < 0 || minutes >= 60 || (hour == 24 && minutes != 0)
      raise EnergySparksUnexpectedStateException.new("Unexpected time of day setting #{hour}:#{minutes}")
    end
    @hour = hour
    @minutes = minutes
    @relative_time = Time.new(1970, 1, 1, hour, minutes, 0)
  end

  def self.time_of_day_from_halfhour_index(hh)
    TimeOfDay.new((hh / 2).to_i, 30 * (hh % 2))
  end

  def to_s
    if @relative_time.day == 1
      @relative_time.strftime('%H:%M')
    elsif @relative_time.day == 2 && @relative_time.hour == 0
      @relative_time.strftime('24:%M')
    else
      '??:??'
    end
  end

  # returns the halfhour index in which the time of day starts,
  # plus the proportion of the way through the half hour bucket the time is
  # code obscificated for performancce
  def to_halfhour_index_with_fraction
    if @minutes == 0
      [@hour * 2, 0.0]
    elsif @minutes == 30
      [@hour * 2 + 1, 0.0]
    elsif @minutes >= 30
      [@hour * 2 + 1, (@minutes - 30) / 30.0]
    else
      [@hour * 2, @minutes / 30.0]
    end
  end

  def strftime(options)
    relative_time.strftime(options)
  end

  def <=>(other)
    other.class == self.class && [hour, minutes] <=> [other.hour, other.minutes]
  end

  def - (value)
    relative_time - value.relative_time
  end
end