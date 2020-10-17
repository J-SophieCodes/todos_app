require 'pg'

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