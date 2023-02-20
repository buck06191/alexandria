use crate::dynamodb::{get_table_contents, upload_to_dynamodb, ArchiveItem};
use aws_sdk_dynamodb::Client;
use lambda_http::{lambda_runtime::Error, Request, RequestExt};

use crate::responses::SuccessResponse;

pub async fn handle_post(client: &Client, request: Request) -> Result<String, Error> {
    let request_json = match request.body() {
        lambda_http::Body::Text(json_string) => json_string,
        _ => "",
    };

    let item: ArchiveItem = serde_json::from_str(request_json)?;

    // Set up DynamoDB connection

    upload_to_dynamodb(client, &item).await?;

    let resp = SuccessResponse {
        req_id: request.lambda_context().request_id,
        body: "Successfully uploaded to DynamoDB".to_owned(),
    };

    let r = serde_json::to_string(&resp)?;

    Ok(r)
}

pub async fn handle_get(client: &Client, request: Request) -> Result<String, Error> {
    // Set up DynamoDB connection

    let contents = get_table_contents(client).await?;

    let resp = SuccessResponse {
        req_id: request.lambda_context().request_id,
        body: serde_json::to_string(&contents)?,
    };

    let r = serde_json::to_string(&resp)?;

    Ok(r)
}
