# Assign a task, start the clock and keep records of the amount of time spent on a job

## LIBRARY MODIFICATION
# Kept simple. Shouldn't be a problem. 
# Not intended to be included in other project
##

class Array
  def sum
    self.reduce {|x, acc| acc += x}
  end
end

class Time
  def today?
    t = Time.new
    t.day == day && t.month == month && t.year == year 
  end

  def self.since_today
    ((t=Time.now) - Time.new(t.year, t.month, t.day)).to_i
  end
  
end


## MARSHALING

def load_marsh file_name
  if File.exist?(file_name) && File.size(file_name) > 0
    File.open(file_name) do |f|
      yield f, true
    end
  else
    yield "", false
  end
end

# def load_marsh_create file_name
#   load_marsh file_name do |f, cond|
#     File.open(file_name, 'w+') if !cond
#     yield f
#   end
# end

## HELPERS

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
  
  def self.stringify unit # Ex : ["min", 23] => "23 mins"
    val = unit.last
    (val > 0) ? val.to_s + ' ' + unit.first + ((val > 1) ? 's ' : ' ') : ''
  end

  def self.add_time
    "(" + @@time_s.to_s + ")"
  end

end


## Main Controller
class Main
  attr_reader :registered_modules

  @@main_file = "MainTaskManager"

  def self.main_load_marsh
    load_marsh @@main_file do |f, cond|
      if cond then @@loader = Marshal.load(f) else @@loader = Tl.new end
    end
  end

  def self.init mod_id = nil
    main_load_marsh
    loader.init mod_id
  end
  
  def self.open mod_id
    loader.init mod_id
  end

  # def self.current_mod
  # end

  def self.loader
    @@loader
  end

  def self.register mod_hash
    loader.register mod_hash
  end

  def self.save
    loader.save
    File.open(@@main_file, 'w+') do |f|  
      Marshal.dump(@@loader, f)  
    end    
  end
  
  def self.current_mod
    loader.current_mod
  end
  
  def self.list
    loader.modules.each_key do |key|
      # m.each {|key| puts "ID => #{key}"}
      puts "ID => #{key}, file => #{loader.modules[key][:file]}"
    end; nil
  end

end


## Task Loader
class Tl
  
  attr_reader :modules, :current_mod, :next_id

  @@dm_calendar = "Calendar"
  
  def initialize 
    @next_id = 0
    @modules = {}
    @current_mod = nil;
  end

  @next_id = 0
  def loader_marsh file
    load_marsh file do |f, cond|
      if cond then @current_mod = Marshal.load(f) else false end
    end
  end

  def init mod_id = nil
    # reopen if mod.nil?
    if !mod_id.nil?
      set_current mod_id
      # loader_load_marsh mod[@current][file]
      Tm.init current_mod
    end
    Dm.open @@dm_calendar
  end

  def load_module file
    loader_marsh file
    Tm.init current_mod ## Will be init twice if base call comes from init
  end

  # Register a new module
  def register mod
    mod = TasksModule.new next_id, mod
    #Little hack, temporary
    tmp = @current_mod; @current_mod = mod; save; @current_mod = tmp
    @modules[@next_id] = {:file => mod.file, :title => mod.title}
  end

  # Loads a module
  def set_current mod_id
    save if !@current_mod.nil?
    @current_mod = modules[mod_id]
    load_module @current_mod[:file]
  end
  
  # def reopen
  #   loader_load_marsh @current[:file]
  # end

  def next_id # If accessor is called, automatically updates id
    @next_id += 1 # To get actual id, use @next_id directly
  end

  # def self.open file = 'Tasks'
  #   @@file = file
  #   self.tm_load_marsh file
  # end

  def save
    File.open(@current_mod.file, 'w+') do |f|  
      Marshal.dump(@current_mod, f)  
    end
    Dm.save
  end

end


## Implements base tasks common to Module and Tasks
class AbstractTaskManager

  attr_reader :id, :file, :module_num, :estimated_time, :diff, :desc, :spent, :status, :tasks, :reflex,
  :time
  
  @@status = [] 

  def init_rest params
    default.each do |sym, val|
      if params.has_key? sym
        instance_variable_set(sym, params[sym]) 
      else 
        set_default sym
      end
    end
  end

  def set_default sym
    if !instance_variable_defined? sym
      instance_variable_set(sym, default[sym]); true
    else
      false
    end    
  end
  
  def reinit t
    default.each { |key, val| t.set_default(key)}
    t
  end  

  def append sym, desc
    instance_variable_set(instance_sym(sym),
                          instance_variable_get(instance_sym(sym)) + desc)
  end


  def instance_sym sym
    sym.to_s.prepend("@")
  end

  def change_status status
    if @@status.include? status
      @status = status
    end
  end

  # quicker Alias for change_status :done
  def done
    change_status :done
  end

  def to_hash
    instance_variables.inject({}) do |acc, var|
      acc.merge({var=>instance_variable_get(var)})
    end
  end

  def copy
    t = Task.new(0,0,0,0)
    instance_variables.each do |var|
      t.instance_variable_set(var, instance_variable_get(var))
    end
    t
  end
  
  def edit params
    params.each do |key, value|
      instance_variable_set(key, value)
    end
    self
  end

  def is_done?
    @status == :done
  end

  def render
    puts "#{@id} | " +
      (!diff.nil? && diff > 0 ? "#{diff} | " : "") + 
      ((pending > 0) ? "Current : #{current_pending + session}s | " : "") +
      " Total : #{(pending > 0) ? current_pending + time : time}" +
      " | #{status} "
    puts add_space(@id.to_s.length) + " |==> #{@desc}"
    puts "\n Reflexion |==> #{@reflex}" if !@reflex.empty?
  end  

  def default
    if !@default.nil?
      @default
    else
      instance_variable_set(:@default, {:@title => "New Module", :@desc=>"", :@spent => 0,
                              :@pending => 0, :@session => 0, :@status => :new, :@reflex => ""})
    end
  end

  private
  
  def pending
    0
  end

  def new # No instantiation
  end

end

## Will wait for mixins for this
class TasksModule < AbstractTaskManager
  


  attr_reader :id, :file, :module_num, :estimated_time, :diff, :desc, :spent, :status, :tasks
  
  @@status = [:new, :pending, :done]
  
  def initialize id, params
    @id = id
    @file = params[:@file]
    raise "File Name can't be nil" if @file.nil?
    # @title = params[:title]
    # @desc = desc
    @tasks = Tasks.new
    init_rest params
  end

  def default
    if !@default.nil?
      @default
    else
      instance_variable_set(:@default, {:@title => "New Module", :@desc=>"", :@spent => 0,
                              :@pending => 0, :@session => 0, :@status => :new, :@reflex => "", :@module_num => 0})
    end
  end

  def render
    puts "\n###"
    puts "Module #{@module_num} - #{@title}"
    super
    puts "###\n\n"
  end

end

class Task < AbstractTaskManager
  attr_reader :id, :mod_id, :diff, :desc, :time, :pending, :status, :reflex, :default, :complete_id
  attr_accessor :session
  
  @@status = [:new, :pending, :stopped, :done]

  def initialize mod_id, id, diff, desc, rest = {}
    @mod_id = mod_id
    @id = id
    @complete_id = "#{mod_id}.#{id}"
    @diff = diff
    @desc = desc
    # @sub_tasks = [] # Yes, might be a todo
    init_rest rest
  end

  def default
    {"@mod_id"=>Main.current_mod.id, "@complete_id" => "#{@mod_id}.#{@id}", 
      "@time" => 0, "@pending" => 0, "@session" => 0, "@status" => :new, "@reflex" => ""}
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
    @session += current_pending
    puts "Running for #{@session}. Saved #{current_pending}"
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
  
  def self.reinit t
    _default.each { |key, val| t.set_default(key)}
    t
  end  
  

  # Short term hack. Will be retought.
  def self._default
    {"@mod_id"=>Main.current_mod.id, "@complete_id" => "#{@mod_id}.#{@id}", 
      "@time" => 0, "@pending" => 0, "@session" => 0, "@status" => :new, "@reflex" => ""}
  end

  def total
    MyTime.format @time
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

  # def self.tm_load_marsh file
  #   load_marsh file do |f, cond|
  #     if cond then @@tasks = Marshal.load(f) else @@tasks = Tasks.new end
  #   end
  # end

  def self.init mod
    @@file = mod.file
    @@mod = mod
  end
  
  def self.mod
    @@mod
  end
  
  # def self.open file = 'Tasks'
  #   @@file = file
  #   self.tm_load_marsh file
  # end
  
  def self.open_backup
    self.tm_load_marsh 'Tasks_backup'
  end

  def self.tasks
    @@mod.tasks
  end

  def self.current 
    tasks.current;
  end


  def self.tasks= (task)
    tasks = task
  end

  def self.start
    tasks.current.start_timer if tasks.current.respond_to? :start_timer
  end

  def self.stop
    Dm.trigger tasks.current if tasks.current.current_pending > 0
    tasks.current.stop_timer if tasks.current.respond_to? :stop_timer
  end
  
  def self.switch id
    self.stop
    self.set_current id
    self.start; self
  end

  def self.last render = nil
    tasks.tasks.last.render if !render.nil?
    tasks.tasks.last if render != :no
  end

  def self.next_id
    last.id + 1
  end
  def self.done
    tasks.current.done
    self
  end

  def self.register (id, diff, desc, *rest)
    tasks.register(Task.new(mod.id, id, diff, desc, *rest))
    last.render
  end

  def self.set_current id
    tasks.set_current id; self
  end

  def self.render status = nil
    mod.render
    tasks.render_not_done; nil
  end

  def self.render_all
    tasks.render_all; nil
  end
  
  def self.render_done
    tasks.render_done; nil
  end

  def self.render_status status
    tasks.render_status status; nil
  end

  def self.current_session
    tasks.current.session
  end

  def self.pending
    tasks.current.current_pending
  end
  
  def self.reinit
    tasks.reinit; self
  end
  
  def self.backup
    File.open('Tasks_backup', 'w+') do |f|
      Marshal.dump(@@tasks, f)
    end
  end
  
  def self.select id
    tasks.select_by_id id
  end

  def self.delete id
    tasks.delete id
  end
  
  def self.total
    MyTime.format tasks.total_time_spent, true
  end

  # def self.close
  #   File.open(@@file, 'w+') do |f|  
  #     self.stop
  #     Marshal.dump(@@tasks, f)  
  #   end
  # end
end

#Day Manager

class Day
  
  attr_reader :init_time, :date, :tasks, :task_running, :time_ran

  def initialize t = Time.new
    @init_time = t
    @date = {"year" => @init_time.year, "month" => @init_time.month, "day" => @init_time.day}
    @tasks = []
    @task_running = {}
    @time_ran = 0
  end

  def init_time= t
    @init_time = t
    @date = {"year" => t.year, "month" => t.month, "day" => t.day}
  end
  
  def register task
    tasks.push task
    task_running[task.complete_id] = task.current_pending
  end
  
  def update task
    task_running[task.complete_id] += task.current_pending
  end

  def trigger task
    (@task_running.include? task.complete_id) ? update(task) : register(task)
    @time_ran += task.current_pending
  end

  def total format = true
    format ? MyTime.format(@time_ran) : @time_ran
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
    @@day = (@@calendar.last.init_time.today?) ? @@calendar.last : next_day
  end
  
  def self.next_day task = nil
    split_task_over_day task if !task.nil? && task.current_pending > Time.since_today
    @@calendar.push Day.new
    @@day = @@calendar.last
  end

  # If task was actually running when day shifted. Split the timer corretly
  def self.split_task_over_day task
    task_yesterday = task.copy

    time_yesterday = task_yesterday.current_pending - Time.since_today
    task_yesterday.edit({"@pending" => Time.now.to_i - time_yesterday}).render
    @@day.trigger task_yesterday # Add to today before changing to next day
    
    midnight_epoch = Time.new((t = Time.now).year, t.month, t.day).to_i # Epoch at 00:00 of today
    task.edit({"@pending" => midnight_epoch, 
                "@time" => task.time + time_yesterday}).render # Needed to keep right timer (task is a reference)
  end

  def self.trigger task
    next_day task if !@@day.init_time.today? # if we changed day since last trigger
    @@day.trigger task
  end

  def self.total format = true
    total = @@calendar.inject(0) do |acc, day|
      acc += day.total false
    end
    format ? MyTime.format(total) : total
  end

  def self.day
    @@day
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

