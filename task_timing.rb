# Assign a task, start the clock and keep records of the amount of time spent on a job

## Library Modif

class Array
  def sum
    self.reduce {|x, acc| acc += x}
  end
end

class Time
  def today?
    t = Time.new
    t.day == self.day && t.month == self.month && t.year == self.year 
  end
end

def load_marsh file_name
  if File.exist?(file_name) && File.size(file_name) > 0
    File.open(file_name) do |f|
      yield f, true
    end
  else
    yield "", false
  end
end

def add_space n
  if n < 1
    ''
  elsif n == 1
    ' '
  else
    ' ' + add_space(n-1)
  end
end

module MyTime
  
  # @@unit_name = {"3600" => "hour", "60" => "min", "1" => "sec"}
  @@unit_name = {"hour" => 3600, "min" => 60, "sec" => 1}
  def self.format_time time
    @@time_s = time
    time_hash = {}
    @@unit_name.inject(time) do |left, unit| # time => {"hour" => x, "min" => y, "sec" => z}
      time_hash.merge!({unit.first => left / unit.last})      
      left %= unit.last
    end; time_hash
  end

  def self.format time, add_time = true
    i, str = 0, ''
    @@time = format_time time
    @@time.inject("") {|str, unit| str += stringify unit} + (add_time ? self.add_time : "")
  end
  
  # transforms [unit, val] to "val" + " unit(s)" where unit is a key of @@unit_name and val, an int
  def self.stringify unit #exemple ["min", 23] => "23 mins"
    val = unit.last
    (val > 0) ? val.to_s + ' ' + unit.first + ((val > 1) ? 's ' : ' ') : ''
  end

  def self.add_time
    "(" + @@time_s.to_s + ")"
  end

end


class Task
  attr_reader :id, :diff, :desc, :time, :pending, :status
  attr_accessor :session
  @@status = [:new, :pending, :stopped, :done]

  @@default = {"@time" => 0, "@pending" => 0, "@session" => 0, "@status" => :new}
  def initialize id, diff, desc, *rest_hash
    @id = id
    @diff = diff
    @desc = desc
    puts rest_hash
    init_rest ((rest_hash.empty?) ? {} : rest_hash[0])
  end


  def init_rest params
    @@default.each do |sym, val|
      puts sym
      if params.has_key? sym
        instance_variable_set(sym, params[sym]) 
      else 
        set_default sym
      end
    end
  end

  def set_default sym
    if !instance_variable_defined? sym
      instance_variable_set(sym, @@default[sym]); true
    else
      false
    end    
  end

  def self.reinit t
    @@default.each { |key, val| t.set_default(key)}
    t
  end  

  def start_timer
    if @pending == 0 || @pending.nil?
      @pending = Time.new.to_i
      puts "timer started for #{@id}"
    else
      puts "Timer already running"
    end
  end

  def current_pending
    (@pending > 0) ? Time.new.to_i - @pending : 0
  end

  def save_timer
    @time += current_pending
    # @session += current_pending
    puts "Running for #{session}. Saved #{current_pending}"
    @pending = Time.new.to_i
    @time
  end

  def stop_timer
    if @pending > 0
      save_timer
      puts "Timer stopped for #{@id}. Now at #{@time}"
    else
      puts "Timer not running"
    end
    @pending = 0
    @session = 0
  end

  def append_desc desc
    @desc += desc
  end

  def change_status status
    if @@status.include? status
      @status = status
    end
  end

  #quicker Alias for change_status :done
  def done
    change_status :done
  end

  def edit params
    params.each do |key, value|
      instance_variable_set(key, value)
    end
  end

  def is_done?
    @status == :done
  end

  def render
    puts "#{@id} | #{@diff} | " + 
      ((@pending > 0) ? 
       "Current : #{current_pending + @session}s | " : "") +
      " Total : #{(pending > 0) ? current_pending + @time : @time}" +
      " | #{@status} "
    puts add_space(@id.to_s.length) + " |==> #{@desc}"
  end

  def total
    MyTime.format @time
  end

  def to_hash
    instance_variables.inject({}) do |acc, var|
      acc.merge({var=>instance_variable_get(var)})
    end
  end

  def print_time
    @time
  end
end

class Tasks
  attr_reader :tasks, :current
  
  def initialize
    @current = 0
    @tasks = []
  end

  def reinit
    tasks = []
    @tasks.each do |t|
      # tasks.push(Task.reinit(t.id, t.diff, t.desc, {time: t.time, pending: t.pending, status: t.status, session: t.session}))
      tasks.push(Task.reinit(t))
    end
    @tasks = tasks
  end
  
  def register task
    @tasks.push task
  end

  def delete id
    (id.respond_to?(:include?)) ? delete_ids(id) : delete_id(id)
    self # Chaining purpose
  end

  def delete_id id
    delete_gen {|t| t.id != id}
  end

  def delete_ids ids
    delete_gen {|t| !(ids.include? t.id)}
  end

  def delete_gen
    @tasks.select! {|t| yield t}
  end
  
  def select_by_id id
    @tasks.select {|t| t.id == id}.first
  end
  
  def set_current id
    if @current.respond_to?(:start_timer)
      if @current.pending > 0 then @current.stop_timer end #if timer is running, stop it
      @tasks[@tasks.index { |t| current.id == t.id }] = @current # and save the task back in the list
    end
    
    @current = @tasks[@tasks.index {|t| t.id == id}] # assign new task
  end
  
  def render_current
    current.render
  end

  def render_many ts
    ts.each do |t|
      t.render
      puts "__________"
    end
  end

  def render_not_done
    render_many(tasks.select {|t| !t.is_done?})
  end
  
  def render_done
    render_status :done
  end

  def render_status status
    render_many(tasks.select {|t| t.status == status})
  end

  def render_all
    render_many tasks
  end
  
  def total_time_spent
    time = 0
    @tasks.each do |t|
      time += t.time
    end
    time
  end

end

module Tm

  def self.tm_load_marsh file
    load_marsh file do |f, cond|
      if cond then @@tasks = Marshal.load(f) else @@tasks = Tasks.new end
    end
  end

  def self.open file = 'Tasks'
    @@file = file
    self.tm_load_marsh file
  end
  
  def self.open_backup
    self.tm_load_marsh 'Tasks_backup'
  end

  def self.tasks
    @@tasks
  end

  def self.current 
    @@tasks.current;
  end


  def self.tasks= (task)
    @@tasks = task
  end

  def self.start
    @@tasks.current.start_timer if @@tasks.current.respond_to? :start_timer
  end

  def self.stop
    Dm.trigger @@tasks.current
    @@tasks.current.stop_timer if @@tasks.current.respond_to? :stop_timer
  end
  
  def self.switch id
    self.stop
    self.set_current id
    self.start; self
  end

  def self.done
    @@tasks.current.done
    self
  end

  def self.register (id, diff, desc, *rest)
    @@tasks.register(Task.new(id, diff, desc, *rest))
  end

  def self.set_current id
    @@tasks.set_current id; self
  end

  def self.render
    @@tasks.render_not_done; nil
  end

  def self.render_all
    @@tasks.render_all; nil
  end
  
  def self.render_done
    @@tasks.render_done; nil
  end

  def self.render_status status
    @@tasks.render_status status; nil
  end

  def self.current_session
    @@tasks.current.session
  end

  def self.pending
    @@tasks.current.current_pending
  end
  
  def self.reinit
    @@tasks.reinit; self
  end
  
  def self.backup
    File.open('Tasks_backup', 'w+') do |f|
      Marshal.dump(@@tasks, f)
    end
  end
  
  def self.select_id id
    @@tasks.select_by_id id
  end

  def self.delete id
    @@tasks.delete id
  end
  
  def self.total
    MyTime::format @@tasks.total_time_spent, true
  end

  def self.close
    File.open(@@file, 'w+') do |f|  
      self.stop
      Marshal.dump(@@tasks, f)  
    end
  end
end

#Day Manager

class Day
  
  attr_reader :init_time, :date, :tasks, :task_running, :time_ran

  def initialize
    @init_time = t = Time.new
    @date = {"year" => @init_time.year, "month" => @init_time.month, "day" => @init_time.day}
    @tasks = []
    @task_running = {}
    @time_ran = 0
  end

  def register task
    tasks.push task
    task_running[task.id] = task.current_pending
  end
    
  def update task
    task_running[task.id] += task.current_pending
  end

  def trigger task
    (@task_running.include? task.id) ? update(task) : register(task)
    @time_ran += task.current_pending
  end

  def total
    MyTime.format @time_ran
  end
end

module Dm
  
  def self.load file
    load_marsh file do |f, cond|
      if cond then @@calendar = Marshal.load(f) else @@calendar = [Day.new] end
    end
  end

  def self.open file = 'Calendar'
    @@file = file
    load file
    init
  end
  
  def self.init
    @@today = (@@calendar.last.init_time.today?) ? @@calendar.last : Day.new
  end
  
  def self.next_day task
    task_yesterday = task
    t = Time.now
    since_today = (t - Time.new(t.year, t.month, t.day)).to_i
    task_yesterday.edit({"@pending" => (task_yesterday.pending - since_today)})
    @@today.trigger task_yesterday
    @@today = Day.new.register task
  end

  def self.trigger task
    next_day task if !@@today.init_time.today? # if we changed day since last trigger
    @@today.trigger task
  end

  def self.today
    @@today
  end
  
  def self.calendar
    @@calendar
  end

  def self.save
    File.open(@@file, 'w+') do |f|  
      Marshal.dump(@@calendar, f)  
    end
  end

  def self.file= file
    @@file = file
  end

end


