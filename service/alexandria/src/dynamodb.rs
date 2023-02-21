use aws_sdk_dynamodb::error::{PutItemError, PutItemErrorKind};
use aws_sdk_dynamodb::output::PutItemOutput;
use aws_sdk_dynamodb::Client;
use log::{error, info};
use serde::{Deserialize, Serialize};

use crate::responses::FailureResponse;

#[derive(Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum Category {
    Capitalism,
    ComputerScience,
    Career,
    Rust,
    Typescript,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ArchiveItem {
    category: Category,
    #[serde(rename = "itemUrl")]
    url: String,
    title: String,
}

impl ArchiveItem {
    #[cfg(test)]
    fn standard_test_item() -> ArchiveItem {
        ArchiveItem {
            category: Category::ComputerScience,
            url: String::from("https://www.example.com"),
            title: String::from("Example"),
        }
    }
}

// Define constants
const TABLE_NAME: &str = "LibraryOfAlexandria";
const LOCALSTACK_ENDPOINT: &str = "http://localhost:8000";

fn use_localstack() -> bool {
    std::env::var("LOCALSTACK").unwrap_or_default() == "true"
}

pub async fn create_dynamodb_client() -> Client {
    let is_local = use_localstack();

    // set up as a DynamoDB client

    let config_loader = aws_config::from_env();

    let config = config_loader.load().await;

    let mut dynamodb_config_builder = aws_sdk_dynamodb::config::Builder::from(&config);

    if is_local {
        info!("Using local stack at endpoint {}", LOCALSTACK_ENDPOINT);
        dynamodb_config_builder = dynamodb_config_builder.endpoint_url(LOCALSTACK_ENDPOINT);
    }

    // dynamodb_config_builder = dynamodb_config_builder.endpoint_url(LOCALSTACK_ENDPOINT);
    let dynamodb_config = dynamodb_config_builder
        .endpoint_url(LOCALSTACK_ENDPOINT)
        .build();
    Client::from_conf(dynamodb_config)
}

fn log_dynamodb_error(dynamodb_error: String) -> FailureResponse {
    error!(
        "failed to put item in {}, error: {:?}",
        TABLE_NAME, dynamodb_error
    );
    FailureResponse {
        body: "The lambda encountered an error and your message was not saved".to_owned(),
    }
}

pub async fn upload_to_dynamodb(
    client: &Client,
    archive_item: &ArchiveItem,
) -> Result<PutItemOutput, FailureResponse> {
    let item = serde_dynamo::to_item(archive_item).map_err(|err| {
        error!("failed to convert item {:?}, error: {}", archive_item, err);
        FailureResponse {
            body: "The lambda encountered an error and could not parse item".to_owned(),
        }
    })?;

    // Store our data in the DB
    let result = client
        .put_item()
        .table_name(TABLE_NAME)
        .set_item(Some(item))
        .send()
        .await;

    match result {
        Ok(output_result) => {
            info!("Successfully uploaded item. {:?}", output_result);
            Ok(output_result)
        }
        Err(err) => match err.into_service_error() {
            PutItemError { kind, .. } => match kind {
                PutItemErrorKind::ResourceNotFoundException(value) => Err(log_dynamodb_error(
                    format!("Resource not found - {:?}", value),
                )),
                PutItemErrorKind::InvalidEndpointException(value) => Err(log_dynamodb_error(
                    format!("Invalid endpoint - {:?}", value),
                )),
                PutItemErrorKind::InternalServerError(value) => Err(log_dynamodb_error(format!(
                    "Internal server error - {:?}",
                    value
                ))),
                PutItemErrorKind::Unhandled(value) => {
                    Err(log_dynamodb_error(format!("Unhandled error - {:?}", value)))
                }
                _ => Err(log_dynamodb_error("Unhandled  by lambda".to_owned())),
            },
        },
    }
}

pub async fn get_table_contents(client: &Client) -> Result<Vec<ArchiveItem>, FailureResponse> {
    let result = client
        .scan()
        .table_name(TABLE_NAME)
        .send()
        .await
        .map_err(|err| {
            error!(
                "failed to scan items in {}, error: {:?}",
                TABLE_NAME,
                err.into_service_error().message()
            );
            FailureResponse {
                body: "The lambda encountered an error and could not retrieve table contents"
                    .to_owned(),
            }
        })?;

    // Parse scan response
    if let Some(items) = result.items().map(|slice| slice.to_vec()) {
        let archive_items: Vec<ArchiveItem> =
            serde_dynamo::from_items(items.clone()).map_err(|err| {
                error!(
                    "failed to parse {:?} from {}, error: {}",
                    &items, TABLE_NAME, err
                );
                FailureResponse {
                    body: "The lambda encountered an error and could not parse table contents"
                        .to_owned(),
                }
            })?;

        Ok(archive_items)
    } else {
        Ok(vec![])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn init_test() {
        let _ = env_logger::builder().is_test(true).try_init();
        std::env::set_var("LOCALSTACK", "true");
    }

    #[tokio::test]
    async fn upload_to_dynamodb_returns_ok() {
        init_test();

        let item = ArchiveItem::standard_test_item();

        let client = create_dynamodb_client().await;

        let resp = upload_to_dynamodb(&client, &item).await;

        assert!(resp.is_ok(),)
    }

    #[tokio::test]
    async fn get_table_contents_returns_values() {
        init_test();

        let item = ArchiveItem::standard_test_item();

        let client = create_dynamodb_client().await;

        let _resp = upload_to_dynamodb(&client, &item).await;

        let scan_resp = get_table_contents(&client).await.unwrap();

        assert!(scan_resp.len() > 0, "Failed to scan local DynamoDB")
    }
}
