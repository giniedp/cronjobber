require "spec_helper"

describe Cronjobber::Task do

  after :each do
    Cronjobber::Task.destroy_all
  end
  
  describe "initialization" do
    before :each do
      class DefaultJob < Cronjobber::Task
        run_task
      end
      
      class CustomizedJob < Cronjobber::Task
        run_task :every => 10.minutes, :in_background => true, :method => :custom_run_method, :at => ["12:34", "56:78"]
      end
      
      module ModulizedJob
        class CustomizedJob < Cronjobber::Task
          run_task :every => 10.minutes, :in_background => true, :method => :custom_run_method, :at => ["12:34", "56:78"]
        end
      end
    end

    it "should fill default values" do
      DefaultJob.cronjob_frequency.should == 0.minutes
      DefaultJob.cronjob_delayed.should be false
      DefaultJob.cronjob_method.should == 'run'
      DefaultJob.cronjob_timesteps.should == []
    end
  
    it "should change frequency" do
      CustomizedJob.cronjob_frequency.should == 10.minutes    
    end
    
    it "should change delay option" do
      CustomizedJob.cronjob_delayed.should be true
    end
    
    it "should change run method" do
      CustomizedJob.cronjob_method.should == "custom_run_method"
    end
    
    it "should initialize with timesteps" do
      CustomizedJob.cronjob_timesteps.should == ["12:34", "56:78"]
    end
    
    it "should generate cronjob name" do
      DefaultJob.cronjob_name.should == "default_job"
      ModulizedJob::CustomizedJob.cronjob_name.should == "modulized_job/customized_job"
    end
  end

  describe "instance" do
    before :each do 
      class TestJob < Cronjobber::Task
        run_task
      end
      
      class FailJob < Cronjobber::Task
        run_task
        
        def run
          raise "job failed with exception message"
        end
      end
      
      class BackgroundJob < Cronjobber::Task
        run_task :in_background => true
        def self.cronjob_enqueue
          # mock with empty method for testing
        end
      end
      
      @job = TestJob.create!({ :run_at => Time.now - 1.day, :name => TestJob.cronjob_name })
      FailJob.create!({ :run_at => Time.now - 1.day, :name => FailJob.cronjob_name })
      BackgroundJob.create!({ :run_at => Time.now - 1.day, :name => BackgroundJob.cronjob_name })
    end

    after :each do
      Cronjobber::Task.destroy_all
    end
    
    it "should lock" do
      @job.locked?.should be false
      @job.lock!.should be true
      @job.locked?.should be true
    end
    
    it "should lock only once" do
      @job.lock!.should be true
      @job.lock!.should be false
    end
    
    it "should unlock" do
      @job.lock!.should be true
      @job.unlock!.should be true
      @job.locked?.should be false
    end

    it "should be locked for invalid key" do
      @job.lock!.should be true
      @job.locked?("123456").should be true
    end
        
    it "should not be locked for valid key" do
      @job.lock!.should be true
      @job.locked?(@job.locking_key).should be false
    end
    
    it "should perform the job" do
      job = TestJob.cronjob_perform
      job.id.should be @job.id
      
      job.locked?.should be false
      job.last_error.should be_nil
      job.duration.should_not be_nil
      job.status.should == "performed"
    end
    
    it "should not perform the job when exception occurs" do
      job = FailJob.cronjob_perform
      job.locked?.should be false
      job.status.should == "exception"
      job.last_error.starts_with?("job failed with exception message").should be true
    end
    
    it "should enqueue the job in background" do
      job = BackgroundJob.cronjob_perform
      job.locked?.should be true
      job.status.should == "enqueued"
      job.last_error.should be_nil
    end
    
    it "should perform background job with valid key" do
      job = BackgroundJob.cronjob_perform
      job.locked?.should be true
      BackgroundJob.cronjob_perform_delayed(job.locking_key)
      job.locked?.should be false
      job.status.should == "performed"
      job.last_error.should be_nil
    end
    
    it "should not perform background job with invalidvalid key" do
      job = BackgroundJob.cronjob_perform
      job.locked?.should be true
      BackgroundJob.cronjob_perform_delayed("some invalid key")
      job.locked?.should be true
      job.status.should == "locked"
    end
  end

  describe "without frequency and without time" do
    before :each do
      class TestJob < Cronjobber::Task
        run_task :every => 0.minutes, :at => []
      end
      @test_job = TestJob.new({ :run_at => Time.parse("2011-1-1 12:00") })
      @test_job.save!
    end
    
    it "should be runable before run_at time" do
      @test_job.should_run?(Time.parse("2011-1-1 11:00")).should be true
    end
    
    it "should be runable on run_at time" do
      @test_job.should_run?(Time.parse("2011-1-1 12:00")).should be true
    end
    
    it "should be runable after run_at time" do
      @test_job.should_run?(Time.parse("2011-1-1 13:00")).should be true
    end
  end
  
  describe "with frequency and without time" do
    before :each do
      class TestJob < Cronjobber::Task
        run_task :every => 10.minutes, :at => []
      end
      @test_job = TestJob.new({ :run_at => Time.parse("2011-1-1 12:00") })
      @test_job.save!
    end
    
    it "should not be runable before run_at time" do
      @test_job.should_run?(Time.parse("2011-1-1 11:00")).should be false
    end
    
    it "should not be runable on run_at time" do
      @test_job.should_run?(Time.parse("2011-1-1 12:00")).should be false
    end
    
    it "should not be runable after run_at time before frequency elapses" do
      @test_job.should_run?(Time.parse("2011-1-1 12:09")).should be false
    end
    
    it "should be runable after run_at time after frequency elapsed" do
      @test_job.should_run?(Time.parse("2011-1-1 12:10")).should be true
    end
  end
  
  describe "without frequency and with time" do
    before :each do
      class TestJob < Cronjobber::Task
        run_task :every => 0.minutes, :at => ["12:00"]
      end
      @test_job = TestJob.new({ :run_at => Time.parse("2011-1-1 12:00") })
      @test_job.save!
    end
    
    it "should not be runable before run_at time" do
      @test_job.should_run?(Time.parse("2010-1-1 11:00")).should be false
      @test_job.should_run?(Time.parse("2011-1-1 11:00")).should be false
      @test_job.should_run?(Time.parse("2011-1-1 11:59")).should be false
    end
    
    it "should not be runable on run_at time" do
      @test_job.should_run?(Time.parse("2011-1-1 12:00")).should be false
    end
    
    it "should be runable after run_at time" do
      @test_job.should_run?(Time.parse("2011-1-1 12:01")).should be true
      @test_job.should_run?(Time.parse("2011-1-1 13:00")).should be true
      @test_job.should_run?(Time.parse("2012-1-1 12:01")).should be true
    end
  end
  
  describe "with frequency and with time" do
    before :each do
      class TestJob < Cronjobber::Task
        run_task :every => 30.minutes, :at => ["12:00"]
      end
      @test_job = TestJob.new({ :run_at => Time.parse("2011-1-1 12:00") })
      @test_job.save!
    end
    
    it "should not be runable before run_at time" do
      @test_job.should_run?(Time.parse("2010-1-1 11:00")).should be false
      @test_job.should_run?(Time.parse("2011-1-1 11:00")).should be false
      @test_job.should_run?(Time.parse("2011-1-1 11:59")).should be false
    end
    
    it "should not be runable after run_at within frequency time" do
      @test_job.should_run?(Time.parse("2011-1-1 12:00")).should be false
      @test_job.should_run?(Time.parse("2011-1-1 12:01")).should be false
      @test_job.should_run?(Time.parse("2011-1-1 12:29")).should be false
    end
    
    it "should be runable after run_at time after frequency time" do
      @test_job.should_run?(Time.parse("2011-1-1 12:30")).should be true
      @test_job.should_run?(Time.parse("2011-1-1 13:31")).should be true
      @test_job.should_run?(Time.parse("2012-1-1 12:00")).should be true
    end
  end
  
end