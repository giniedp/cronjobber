class CreateCronjobs < ActiveRecord::Migration
  def self.up
    create_table(:cronjobs) do |t|
      t.string :name
      t.datetime :run_at
      t.datetime :locked_at
      t.string :locking_key
      t.integer :duration
      t.text :last_error
      t.integer :total_runs
      t.integer :total_failures
    end
  end

  def self.down
    drop_table(:cronjobs)
  end
end
