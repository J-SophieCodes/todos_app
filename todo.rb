require 'sinatra'
require 'sinatra/reloader' #if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  @storage = SessionPersistence.new(session)
end

helpers do
  def todos_remaining(todolist)
    todolist[:todos].count { |todo| !todo[:completed] }
  end

  def todos_count(todolist)
    todolist[:todos].size
  end

  def all_done?(todolist)
    todos_remaining(todolist) == 0 && todos_count(todolist) > 0
  end

  def list_class(todolist)
    "complete" if all_done?(todolist)
  end

  def sort_lists(lists, &block)
    lists.sort_by { |list| all_done?(list) ? 1 : 0 }.each(&block)
  end

  def sort_todos(todos, &block)
    todos.sort_by { |todo| todo[:completed] ? 1 : 0 }.each(&block)
  end
end

class SessionPersistence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(index)
    find_item(index, all_lists)
  end

  def all_lists
    @session[:lists]
  end

  def existing_list?(list_name)
    all_lists.any? { |list| list[:name].downcase == list_name.downcase }
  end

  def new_list(list_name)
    index = next_idx(all_lists)
    all_lists << { idx: index, name: list_name, todos: [] }
  end

  def delete_list(index)
    delete_item(index, all_lists)
  end

  def update_list_name(index, new_name)
    list = find_list(index)
    list[:name] = new_name
  end

  def create_new_todo(list_idx, todo)
    list = find_list(list_idx)
    item_idx = next_idx(list[:todos])
    list[:todos] << { idx: item_idx, name: todo, completed: false }
  end

  def existing_todo?(list_idx, todo)
    list = find_list(list_idx)
    list[:todos].any? { |item| item[:name].downcase == todo.downcase }
  end

  def delete_todo(list_idx, item_idx)
    list = find_list(list_idx)
    delete_item(item_idx, list[:todos])
  end

  def update_todo_status(list_idx, item_idx, new_status)
    list = find_list(list_idx)
    todo = find_item(item_idx, list[:todos])
    todo[:completed] = new_status
  end

  def mark_all_todos_as_completed(list_idx)
    list = find_list(list_idx)
    list[:todos].each { |todo| todo[:completed] = true }
  end

  private

  # Returns the next index in a list of todos or in a list of lists
  def next_idx(list)
    return 0 if list.empty?
    list.map { |item| item[:idx] }.max + 1
  end

  # Delete item from a list of todos or from a list of lists
  def delete_item(idx, list)
    list.reject! { |item| item[:idx] == idx }
  end

  # Returns item from a list of todos or from a list of lists
  def find_item(idx, list)
    list.find { |item| item[:idx] == idx }
  end
end

# Returns specified list from all lists
def load_list(index)
  list = @storage.find_list(index)
  return list if list

  session[:error] = 'The specified list was not found.'
  redirect '/lists'
end

# Return an error message if the name is invalid. Otherwise, return nil.
def detect_list_name_error(list_name)
  if !(1..100).cover? list_name.size
    'List name must be between 1 and 100 characters.'
  elsif @storage.existing_list?(list_name)
    "There is an existing '#{list_name}' list. Please provide a unique list name."
  end
end

# Return an error message if the name is invalid. Otherwise, return nil.
def detect_item_name_error(list_idx, todo)
  if todo.nil? || todo.length.zero?
    'Item description must be at least 1 character in length.'
  elsif @storage.existing_todo?(list_idx, todo)
    "'#{todo}' is already on the list."
  end
end

# Redirect visit to homepage
get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = @storage.all_lists

  erb :lists
end

# Render the new list form
get '/lists/new' do
  erb :new_list
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip.squeeze(" ")

  error = detect_list_name_error(list_name)
  if error
    session[:error] = error
    erb :new_list
  else
    @storage.new_list(list_name)
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# View a todo list
get '/lists/:index' do
  @index = params[:index].to_i
  @todo_list = load_list(@index)

  erb :todo_list
end

# Edit an existing todo list
get '/lists/:index/edit' do
  @index = params[:index].to_i
  @todo_list = load_list(@index)

  erb :edit_list
end

# Update an existing todo list
post '/lists/:index' do
  @index = params[:index].to_i
  @todo_list = load_list(@index)
  @list_name = params[:list_name].strip.squeeze(" ")

  error = detect_list_name_error(@list_name)
  if error
    session[:error] = error
    erb :edit_list
  else
    @storage.update_list_name(@index, @list_name)
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{@index}"
  end
end

# Delete an existing todo list
post '/lists/:index/destroy' do
  index = params[:index].to_i
  @storage.delete_list(index)
  session[:success] = 'The list has been deleted.'
  
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    redirect "/lists"
  end
end

# Add a todo item
post '/lists/:index/todos' do
  @index = params[:index].to_i
  @todo_list = load_list(@index)
  @todo = params[:todo].strip.squeeze(" ")

  error = detect_item_name_error(@index, @todo)
  if error
    session[:error] = error
    erb :todo_list
  else
    @storage.create_new_todo(@index, @todo)
    session[:success] = 'The todo item has been added.'
    redirect "/lists/#{@index}"
  end
end

# Delete a todo item
post '/lists/:index/todos/:item_idx/destroy' do
  @index = params[:index].to_i
  item_idx = params[:item_idx].to_i
  @storage.delete_todo(@index, item_idx)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = 'The item has been deleted.'
    redirect "/lists/#{@index}"
  end
end

# Update status of a todo item
post '/lists/:index/todos/:item_idx' do
  @index = params[:index].to_i
  item_idx = params[:item_idx].to_i
  is_completed = params[:completed] == "true"

  @storage.update_todo_status(@index, item_idx, is_completed)

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@index}"
end

# To complete all todos
post '/lists/:index/complete_all' do
  @index = params[:index].to_i
  @storage.mark_all_todos_as_completed(@index)

  session[:success] = 'All done!'
  redirect "/lists/#{@index}"
end
