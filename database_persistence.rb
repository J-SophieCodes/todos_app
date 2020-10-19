require 'pg'

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info "#{statement} : #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(index)
    sql = <<~SQL
      SELECT lists.*,
      COUNT(todos.id) AS todos_count,
      COUNT(NULLIF(todos.completed, true)) AS todos_remaining_count
      FROM lists
      LEFT JOIN todos ON todos.list_id = lists.id
      WHERE lists.id = $1
      GROUP BY lists.id
      ORDER BY todos_remaining_count DESC, lists.name;
    SQL
    
    result = query(sql, index)
    tuple_to_list_hash(result.first)
  end

  def all_lists
    sql = <<~SQL
      SELECT lists.*,
      COUNT(todos.id) AS todos_count,
      COUNT(NULLIF(todos.completed, true)) AS todos_remaining_count
      FROM lists
      LEFT JOIN todos ON todos.list_id = lists.id
      GROUP BY lists.id
      ORDER BY todos_remaining_count DESC, lists.name;
    SQL

    result = query(sql)

    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end

  def existing_list?(list_name)
    sql = "SELECT * FROM lists WHERE name ILIKE $1;"
    result = query(sql, list_name)
    !result.ntuples.zero?
  end

  def new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1);"
    query(sql, list_name)
  end

  def delete_list(index)
    sql = "DELETE FROM lists WHERE id = $1;"
    query(sql, index)
  end

  def update_list_name(index, new_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2;"
    query(sql, new_name, index)
  end

  def create_new_todo(list_idx, todo)
    sql = "INSERT INTO todos (name, list_id) VALUES ($1, $2);"
    query(sql, todo, list_idx)
  end

  def existing_todo?(list_idx, todo)
    sql = "SELECT * FROM todos WHERE list_id = $1 AND name ILIKE $2;"
    result = query(sql, list_idx, todo)
    !result.ntuples.zero?
  end

  def delete_todo(list_idx, item_idx)
    sql = "DELETE FROM todos WHERE list_id = $1 AND id = $2;"
    query(sql, list_idx, item_idx)
  end

  def update_todo_status(list_idx, item_idx, new_status)
    sql = "UPDATE todos SET completed = $1 WHERE list_id = $2 AND id = $3;"
    query(sql, new_status, list_idx, item_idx)
  end

  def mark_all_todos_as_completed(list_idx)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1;"
    query(sql, list_idx)
  end

  def find_todos_for_list(list_id)
    todos_sql = "SELECT * FROM todos WHERE list_id = $1"
    todos_result = query(todos_sql, list_id)

    todos_result.map do |todo_tuple|
      { idx: todo_tuple["id"].to_i,
        name: todo_tuple["name"],
        completed: todo_tuple["completed"] == "t" }
    end
  end

  private

  def tuple_to_list_hash(tuple)
    { idx: tuple["id"].to_i,
      name: tuple["name"],
      todos_count: tuple["todos_count"].to_i,
      todos_remaining_count: tuple["todos_remaining_count"].to_i }
  end
end