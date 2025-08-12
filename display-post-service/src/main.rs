use axum::{
    extract::State,
    response::{Html, IntoResponse},
    routing::get,
    Router,
};
use askama::Template;
use std::net::SocketAddr;
use std::sync::Arc;
use tracing;
use tracing_subscriber;

#[derive(Template)]
#[template(path = "posts.html")]
struct PostsTemplate<'a> {
    posts: &'a [String],
}

async fn display_posts(State(posts): State<Arc<Vec<String>>>) -> impl IntoResponse {
    let html = PostsTemplate { posts: &posts }.render().unwrap();
    Html(html)
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let posts: Arc<Vec<String>> = Arc::new(vec![
        "Post 1: Hello World".to_string(),
        "Post 2: Rust is Great".to_string(),
    ]);

    let app = Router::new()
        .route("/posts", get(display_posts))
        .with_state(posts);

    let addr = SocketAddr::from(([0, 0, 0, 0], 3002));
    println!("Posts service listening on {}", addr);
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}