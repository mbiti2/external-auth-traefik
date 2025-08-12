use axum::{
    extract::State,
    response::{Html, IntoResponse},
    routing::get,
    Router,
};
use askama::Template;
use std::net::SocketAddr;
use std::sync::Arc;
use tracing_subscriber;

#[derive(Template)]
#[template(path = "food.html")]
struct FoodTemplate<'a> {
    foods: &'a [String],
}

async fn display_food(State(foods): State<Arc<Vec<String>>>) -> impl IntoResponse {
    let html = FoodTemplate { foods: &foods }.render().unwrap();
    Html(html)
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let foods: Arc<Vec<String>> = Arc::new(vec![
        "Pizza".to_string(),
        "Sushi".to_string(),
        "Burger".to_string(),
    ]);

    let app = Router::new()
        .route("/", get(display_food))
        .with_state(foods);

    let addr = SocketAddr::from(([0, 0, 0, 0], 3001));
    println!("Food service listening on {}", addr);
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}