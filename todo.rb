require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
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
    indexed_lists = {}
    lists.each_with_index { |list, idx| indexed_lists[list] = idx }
    indexed_lists.sort_by { |list, idx| all_done?(list) ? 1 : 0 }.each(&block)
  end

  def sort_todos(todos, &block)
    indexed_todos = {}
    todos.each_with_index { |todo, idx| indexed_todos[todo] = idx }
    indexed_todos.sort_by { |todo, idx| todo[:completed] ? 1 : 0 }.each(&block)
  end
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = session[:lists]

  erb :lists
end

# Render the new list form
get '/lists/new' do
  erb :new_list
end

# Return an error message if the name is invalid. Otherwise, return nil.
def detect_list_name_error(list_name)
  if !(1..100).cover? list_name.size
    'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name].downcase == list_name.downcase }
    "There is an existing '#{list_name}' list. Please provide a unique list name."
  end
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip.squeeze(" ")

  error = detect_list_name_error(list_name)
  if error
    session[:error] = error
    erb :new_list
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

get '/lists/:index' do
  @index = params[:index].to_i
  @todo_list = session[:lists][@index]

  erb :todo_list
end

#  Edit an existing todo list
get '/lists/:index/edit' do
  @index = params[:index].to_i
  @todo_list = session[:lists][@index]

  erb :edit_list
end

# Update an existing todo list
post '/lists/:index' do
  @index = params[:index].to_i
  @todo_list = session[:lists][@index]
  @list_name = params[:list_name].strip.squeeze(" ")

  error = detect_list_name_error(@list_name)
  if error
    session[:error] = error
    erb :edit_list
  else
    @todo_list[:name] = @list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{@index}"
  end
end

#  Delete an existing todo list
post '/lists/:index/destroy' do
  index = params[:index].to_i
  session[:lists].delete_at(index)
  session[:success] = 'The list has been deleted.'

  redirect "/lists"
end

# Return an error message if the name is invalid. Otherwise, return nil.
def detect_item_name_error(todo, todolist)
  if todo.nil? || todo.length.zero?
    'Item description must be at least 1 character in length.'
  elsif todolist.any? { |item| item[:name].downcase == todo.downcase }
    "'#{todo}' is already on the list."
  end
end

# Add a todo item
post '/lists/:index/todos' do
  @index = params[:index].to_i
  @todo_list = session[:lists][@index]
  @todo = params[:todo].strip.squeeze(" ")

  error = detect_item_name_error(@todo, @todo_list[:todos])
  if error
    session[:error] = error
    erb :todo_list
  else
    @todo_list[:todos] << { name: @todo, completed: false }
    session[:success] = 'The todo item has been added.'
    redirect "/lists/#{@index}"
  end
end

# Delete a todo item
post '/lists/:index/todos/:item_idx/destroy' do
  index = params[:index].to_i
  item_idx = params[:item_idx].to_i
  session[:lists][index][:todos].delete_at(item_idx)
  session[:success] = 'The item has been deleted.'

  redirect "/lists/#{index}"
end

# Check off a completed item  
post '/lists/:index/todos/:item_idx' do
  index = params[:index].to_i
  item_idx = params[:item_idx].to_i
  item = session[:lists][index][:todos][item_idx]

  item[:completed] = params[:completed] == "true"
  session[:success] = "'#{item[:name]}' is completed." if item[:completed]

  redirect "/lists/#{index}"
end

# To complete all todos
post '/lists/:index/complete_all' do
  index = params[:index].to_i
  session[:lists][index][:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = 'All done!'

  redirect "/lists/#{index}"
end
