# Alexandria

A project to create a public bookmarks list for itsjoshb.com

## Structure

The service works by using a lambda to write data to DynamoDB. This data can then be read to
create the public bookmarks list.

## Testing

With Docker desktop running, the `scripts/init_db.sh` script will create a local instance of
DynamoDB. Currently tests are only set up for the writing and reading of data from DynamoDB.
More should follow soon.
