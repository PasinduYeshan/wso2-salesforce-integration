#!/bin/bash

IS_BASE_PATH="https://localhost:9443"
USERNAME="admin"
PASSWORD="admin"

# Base64 encoding of username and password
encoded_credentials=$(echo "$USERNAME:$PASSWORD" | base64)

# Function to create B2B Application
create_b2b_app() {
    curl --location --request PATCH "$IS_BASE_PATH/api/server/v1/self-service/preferences" \
    --header "Content-Type: application/json" \
    --header "Authorization: Basic $encoded_credentials" \
    --data '{
        "operation": "UPDATE",
        "properties": [
            {
                "name": "Organization.SelfService.Enable",
                "value": "true"
            }
        ]
    }'
}

# Function to get Application ID
get_application_id() {
    # API Endpoint to retrieve application ID
    api_endpoint="$IS_BASE_PATH/api/server/v1/applications?filter=name+eq+B2B-Self-Service-Mgt-Application"

    # Send request and capture the response
    response=$(curl --location "$api_endpoint" \
        --header "Authorization: Basic $encoded_credentials" \
        --silent)

    # Parse the response to extract the application ID
    application_id=$(echo $response | jq -r '.applications[0].id')

    # Return the application ID
    echo "$application_id"
}

get_api_resource_id() {
    local resource_identifier=$1

    # Send request to retrieve API resources
    response=$(curl --location "https://is.wso2isdemo.com/t/carbon.super/api/server/v1/api-resources?limit=100" \
        --header "Authorization: Basic $encoded_credentials" \
        --silent)

    # Check if response is empty or an error occurred
    if [ -z "$response" ]; then
        echo "Error: No response from API."
        return
    fi

    # Parse the response to extract the API resource ID
    api_resource_id=$(echo $response | jq -r ".apiResources[] | select(.identifier == \"$resource_identifier\") | .id")

    # Check if API resource ID is found
    if [ -z "$api_resource_id" ] || [ "$api_resource_id" == "null" ]; then
        echo "Error: API Resource ID not found for $resource_identifier."
        return
    fi

    # Return the API resource ID
    echo "$api_resource_id"
}

# Function to add Bulk User Management Scope to B2B Application
add_bulk_user_management_scope() {
    app_id=$(get_application_id)
    bulk_api_resource_id=$(get_api_resource_id "/o/scim2/Bulk")
    governance_api_resource_id=$(get_api_resource_id "/o/api/server/v1/identity-governance")
    
    # Check if Application ID is present
    if [ -n "$app_id" ] && [ "$app_id" != "null" ]; then
        curl --location --request POST "$IS_BASE_PATH/api/server/v1/applications/$app_id/authorized-apis" \
        --header "Content-Type: application/json" \
        --header "Authorization: Basic $encoded_credentials" \
        --data "{
            "id":"$bulk_api_resource_id",
            "policyIdentifier":"RBAC",
            "scopes":["internal_org_bulk_mgt_create","internal_org_bulk_mgt_delete","internal_org_bulk_mgt_update","internal_org_bulk_mgt_view"]
        }"

        curl --location --request POST "$IS_BASE_PATH/api/server/v1/applications/$app_id/authorized-apis" \
        --header "Content-Type: application/json" \
        --header "Authorization: Basic $encoded_credentials" \
        --data "{
            "id":"$governance_api_resource_id",
            "policyIdentifier":"RBAC",
            "scopes":["internal_governance_view","internal_governance_update","internal_org_governance_view","internal_org_governance_update"]
        }"
    else
        echo "Error: Application ID not found."
    fi
}

create_b2b_app
add_bulk_user_management_scope
