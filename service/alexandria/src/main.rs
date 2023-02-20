extern crate alexandria;

use alexandria::{
    dynamodb::create_dynamodb_client,
    lambda::{handle_get, handle_post},
};
use lambda_http::{http::Method, lambda_runtime::Error, service_fn, IntoResponse, Request};
use log::info;

async fn function_handler(request: Request) -> Result<impl IntoResponse, Error> {
    let client = create_dynamodb_client().await;

    match request.method() {
        &Method::GET => handle_get(&client, request).await,
        &Method::POST => handle_post(&client, request).await,
        _ => Ok("Unsupported method".to_owned()),
    }
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        // disable printing the name of the module in every log line.
        .with_target(false)
        // disabling time is handy because CloudWatch will add the ingestion time.
        .without_time()
        .init();

    info!("Logger started");

    lambda_http::run(service_fn(function_handler)).await?;
    Ok(())
}
