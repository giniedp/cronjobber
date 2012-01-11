require "cronjobber"
require "cronjobber/tasks_helper"

module Cronjobber
  
  mattr_accessor :tasks
  @@tasks = []
  
  def self.setup
    yield self
  end
  
  class Engine < Rails::Engine#:nodoc:
    config.cronjobber = Cronjobber
    
    initializer "cronjobber.initialize" do |app|
      app.config.cronjobber = Cronjobber
      ActionController::Base.send :include, Cronjobber::TasksHelper
    end
  end
end
