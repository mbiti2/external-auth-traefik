use axum::{
    extract::{Path, State},
    response::{Html, IntoResponse, Redirect},
    routing::{get, post},
    Router,
};
use askama::Template;
use serde::Deserialize;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::Mutex;
use tracing_subscriber;
use uuid::Uuid;

#[derive(Template)]
#[template(path = "todos.html")]
struct TodosTemplate<'a> {
    todos: &'a [TodoItem],
}

#[derive(Debug, Deserialize, Clone)]
struct TodoItem {
    id: Uuid,
    title: String,
    completed: bool,
}

type TodoList = Arc<Mutex<Vec<TodoItem>>>;

#[derive(Deserialize)]
struct NewTodo {
    title: String,
}

#[axum::debug_handler]
async fn index(State(todos): State<TodoList>) -> impl IntoResponse {
    let todos = todos.lock().await;
    let html = TodosTemplate { todos: &todos }.render().unwrap();
    Html(html)
}

#[axum::debug_handler]
async fn add_todo(
    State(todos): State<TodoList>,
    axum::extract::Form(input): axum::extract::Form<NewTodo>,
) -> impl IntoResponse {
    let mut todos = todos.lock().await;
    let todo = TodoItem {
        id: Uuid::new_v4(),  // Use Uuid::new_v4() directly
        title: input.title,
        completed: false,
    };
    todos.push(todo);
    Redirect::to("/todos")
}

#[axum::debug_handler]
async fn toggle_todo(
    Path(id): Path<Uuid>,
    State(todos): State<TodoList>,
) -> impl IntoResponse {
    let mut todos = todos.lock().await;
    if let Some(todo) = todos.iter_mut().find(|t| t.id == id) {
        todo.completed = !todo.completed;
    }
    Redirect::to("/todos")
}

#[axum::debug_handler]
async fn delete_todo(
    Path(id): Path<Uuid>,
    State(todos): State<TodoList>,
) -> impl IntoResponse {
    let mut todos = todos.lock().await;
    todos.retain(|t| t.id != id);
    Redirect::to("/todos")
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let todos: TodoList = Arc::new(Mutex::new(Vec::new()));

    let app = Router::new()
        .route("/todos", get(index))
        .route("/add", post(add_todo))
        .route("/toggle/:id", post(toggle_todo))
        .route("/delete/:id", post(delete_todo))
        .with_state(todos);

    let addr = SocketAddr::from(([0, 0, 0, 0], 3003));
    println!("Todos service listening on {}", addr);
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}