class Cronjobber::Task < ActiveRecord::Base
  set_table_name "cronjobs"  
  attr_accessor :status
  
  def initialize options={}
    raise "#{self.class.name} is abstract" if self.class == Cronjobber::Task
    super options
  end

  def self.cronjob_name
    self.name.underscore
  end

  def self.cronjob
    @cronjob ||= self.find_by_name(self.cronjob_name)
    @cronjob ||= self.create!(:name => self.cronjob_name)
    @cronjob
  end
  
  def self.cronjob_enqueue(key=nil)
    self.delay.cronjob_perform_delayed(key)
  end
  
  def self.cronjob_perform
    key = DateTime.now.to_i
    
    unless cronjob.lock!(key)
      cronjob.status = "locked"
      return cronjob
    end
    
    unless cronjob.should_run?
      cronjob.status = "skipped"
      cronjob.unlock!
      return cronjob
    end
    
    if self.cronjob_delayed
      self.cronjob_enqueue(key)
      cronjob.status = "enqueued"
      cronjob.last_error = nil
      cronjob.save!
    else
      cronjob.send(self.cronjob_method)
      cronjob.status = "performed"
      cronjob.unlock!
    end
    
    return cronjob
  rescue Exception => exception
    cronjob.status = "exception"
    cronjob.unlock!(exception)
    return cronjob
  end
  
  def self.cronjob_perform_delayed(key)
    if cronjob.locked?(key)
      cronjob.status = "locked"
    else
      cronjob.send(self.cronjob_method)
      cronjob.status = "performed"
      cronjob.unlock!
    end
  rescue Exception => exception
    cronjob.status = "exception"
    cronjob.unlock!(exception)
  end
  
  def locked?(key=nil)
    if key && self.locking_key.to_s == key.to_s
      false
    else
      !self.locked_at.nil?
    end
  end
  
  def lock!(key=nil)
    return false if self.locked?
    return self.update_attributes!(:locked_at => DateTime.now, :locking_key => key)
  end
  
  def unlock! exception=nil
    if exception
      self.last_error = [exception.message, exception.backtrace].flatten.join("\n")
      self.total_failures = self.total_failures.to_i + 1
    else
      self.last_error = nil
    end
  
    self.total_runs = self.total_runs.to_i + 1
    self.duration = (Time.now - self.locked_at.to_time) * 1000 if self.locked_at
    self.locked_at = nil
    self.locking_key = nil
    self.run_at = Time.now
    self.save!
  end
  
  def self.cronjob_timepoint t1, t2
    result = []
    t1.to_date.upto(t2.to_date) do |date|
      self.cronjob_timesteps.each do |time|
        result << Time.parse([date.year, date.month, date.day].join("-") + " " + time.to_s) 
      end
    end
    result.sort.uniq.select { |time| (time > t1 && time < t2) }.first
  end
  
  def should_run?(run_at=nil)
    run_at ||= Time.now
    t1, t2 = (self.run_at || run_at), run_at

    if self.class.cronjob_frequency.to_i == 0
      if self.class.cronjob_timesteps.empty?
        true
      else
        self.class.cronjob_timepoint(t1, t2 + 1.day).present?
      end
    else
      if self.class.cronjob_timesteps.empty?
        (t2 - self.class.cronjob_frequency.to_i.seconds) >= t1
      else
        t3 = Time.parse("#{t1.year}-#{t1.month}-#{t1.day} #{self.class.cronjob_timesteps.first}")
        until t3 > t2 do
          t3 += self.class.cronjob_frequency
          return true if t3 > t1 && t3 <= t2
        end
        false
      end
    end
  end
  
  def run
    
  end
  
  def format
    "#{self.class.cronjob_name} # #{self.status} # #{self.duration}ms # #{self.last_error.to_s[0..64]}"
  end
  
  protected
  def self.run_task *arg
    options = arg.extract_options!
    options = { :every => 0.minutes, :in_background => false, :method => :run }.merge(options)
    options[:method] = arg.first if arg.first.is_a?(Symbol)
    
    timesteps = Array(options[:at]).compact
    if !timesteps.empty? && timesteps.any? { |time| !time.to_s.match(/\d\d:\d\d/) }
      raise "Invalid cronjob definition. Only 'hh:mm' is supported"
    end
    
    class_eval %{
      def self.cronjob_frequency
        #{options[:every].to_i}.seconds
      end
      
      def self.cronjob_timesteps
        '#{timesteps.join(',')}'.split(',')
      end
      
      def self.cronjob_delayed
        '#{options[:in_background].to_s}' == 'true'
      end
      
      def self.cronjob_method
        method = '#{options[:method].to_s}'
        method.blank? ? :run : method
      end
    }
  end
end
