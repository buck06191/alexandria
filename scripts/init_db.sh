#!/usr/bin/env bash
# set -x
set -eo pipefail

# Check aws CLI is installed.
if ! [ -x "$(command -v aws)" ]; then
  echo >&2 "Error: aws-cli is not installed."
  exit 1
fi


# Check if a custom port has been set, otherwise default to '5432'
DB_PORT="${DYNAMODB_PORT:=8000}"



# Allow to skip Docker if a dockerized Postgres database is already running
create_dynamodb () {
  if [[ -z "${SKIP_DOCKER}" ]]
  then
    NAME="test-dynamodb"
    CONTAINER=`docker ps -aq -f name=${NAME}`
    if [ $CONTAINER ]; then
        # cleanup
        >&2 echo "Cleaning up existing docker container"
        docker stop $CONTAINER
        docker rm "/${NAME}" 
    fi
    docker run \
      -d \
      --name "${NAME}" \
      -p "${DB_PORT}":8000 \
      amazon/dynamodb-local

    sleep 1
  fi
}

create_table () {
  aws dynamodb create-table \
  --table-name LibraryOfAlexandria \
  --attribute-definitions AttributeName=category,AttributeType=S AttributeName=itemUrl,AttributeType=S \
  --key-schema AttributeName=category,KeyType=HASH AttributeName=itemUrl,KeyType=RANGE\
  --billing-mode PAY_PER_REQUEST \
  --endpoint-url http://localhost:8000 \
  --no-cli-pager
}


create_dynamodb && create_table

table_status () {
  echo `aws dynamodb describe-table \
   --endpoint-url http://localhost:8000 \
   --table-name LibraryOfAlexandria \
   --output json | \
   jq -r .Table.TableStatus`
 }

 until [ $(table_status) == "ACTIVE" ]; do
   TABLE_STATUS=$(table_status)
   >&2 echo "DynamoDB table is ${TABLE_STATUS} - sleeping"
  sleep 1
done

#
#
# >&2 echo "Postgres is up and running on port ${DB_PORT} - running migrations now!"
# export DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}
# sqlx database create
# sqlx migrate run
# >&2 echo "Postgres has been migrated, ready to go!"
