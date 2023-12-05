// Copyright (c) 2023, WSO2 LLC. (https://www.wso2.com) All Rights Reserved.
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http; 
import ballerina/mime;
import ballerina/log;

import wso2_salesforce_integration.config;
import wso2_salesforce_integration.models;
import wso2_salesforce_integration.utils;

public isolated function createSubOrganizationAdmin(models:SalesforcePayload payload) returns json|error {

    // Get the access token.
    string|error accessToken = getAccessToken();
    if (accessToken is error) {
        log:printError("Error while getting access token.");
        return error("Error while getting access token.");
    }

    // Check if the organization name is available.
    boolean|error isOrgNameAvailable = isOrganizationNameAvailable(payload.orgName, <string>accessToken);
    if (isOrgNameAvailable is error) {
        log:printError("Error while checking organization name availability.");
        return error("Error while checking organization name availability.");
    }

    if (!isOrgNameAvailable) {
        log:printError("Organization name is not available.");
        return error("Organization name is not available.");
    }

    // Creaet a sub organization.
    string|error subOrganizationId = createOrganization(payload.orgName, <string>accessToken);
    if (subOrganizationId is error) {
        log:printError("Error while creating sub organization.");
        return error("Error while creating sub organization.");
    }
    
    // Get sub organization token.
    string|error subOrganizationToken = getSubOrganizationToken(accessToken, subOrganizationId);
    if (subOrganizationToken is error) {
        log:printError("Error while getting sub organization token.");
        return error("Error while getting sub organization token.");
    }

    // Change account recovery regex.
    json|error changeAccountRecoveryRegexResponse = changeAccountRecoveryRegex(<string>subOrganizationToken);
    if (changeAccountRecoveryRegexResponse is error) {
        log:printError("Error while changing account recovery regex.");
        return error("Error while changing account recovery regex.");
    }

    // Get admin role id.
    string|error adminRoleId = getApplicationRoleId(<string>subOrganizationToken);
    if (adminRoleId is error) {
        log:printError("Error while getting admin role id.");
        return error("Error while getting admin role id.");
    }

    // Create the user in the sub organization.
    json|error userResponse = createUser(payload, <string> adminRoleId, <string>subOrganizationToken);
    if (userResponse is error) {
        log:printError("Error while creating user.");
        return error("Error while creating user.");
    }
    return userResponse;
}

// Get access token from the token endpoint.
isolated function getAccessToken() returns string|error {

    http:Client clientTokenEndpoint = check new (
        config:tokenEndpoint, 
        httpVersion = http:HTTP_1_1,
        secureSocket = {
            cert: {
                path: config:truststorePath,
                password: config:truststorePassword
            }
        }
    );

    json tokenResponse = check clientTokenEndpoint->post(
        "",
        {
        "grant_type": "client_credentials",
        "scope": "SYSTEM"
    },
    {
        "Authorization": string `Basic ${utils:getBasicAuth()}`
    },
        mime:APPLICATION_FORM_URLENCODED
    );
    
    return <string> check tokenResponse.access_token;
}

// Check if the organization name is available.
isolated function isOrganizationNameAvailable(string organizationName, string accessToken) returns boolean|error {

    http:Client checkOrganizationNameEndpoint = check new (
        config:apiServerEndpoint, 
        httpVersion = http:HTTP_1_1,
        secureSocket = {
            cert: {
                path: config:truststorePath,
                password: config:truststorePassword
            }
        }
    );

    json organizationNameAvailabilityResponse = check checkOrganizationNameEndpoint->post(
            "/organizations/check-name",
        {
            "name": organizationName
        },
        {
            "Authorization": string `Bearer ${accessToken}`
        },
            mime:APPLICATION_JSON
    );

    return <boolean> check organizationNameAvailabilityResponse.available;
}

// Create a sub organization.
isolated function createOrganization(string organizationName, string accessToken) returns string|error {

    http:Client createSubOrganizationEndpoint = check new (
        config:apiServerEndpoint, 
        httpVersion = http:HTTP_1_1,
        secureSocket = {
            cert: {
                path: config:truststorePath,
                password: config:truststorePassword
            }
        }
    );

    http:Response response = check createSubOrganizationEndpoint->post(
        "/organizations",
        {
            "name": organizationName
        },
        {
            "Authorization": string `Bearer ${accessToken}`
        },
        mime:APPLICATION_JSON
    );

    if (response.statusCode != 201) {
        return error ("Error while creating sub organization.");
    }

    // Process successful response.
    json subOrgCreationResponseBody = check response.getJsonPayload();
    json subOrgIdJson = check subOrgCreationResponseBody.id;
    return subOrgIdJson.toString();
}

// Get a token for sub organization.
isolated function getSubOrganizationToken(string accessToken, string subOrganizationId) returns string|error {

    http:Client clientTokenEndpoint = check new (
        config:tokenEndpoint, 
        httpVersion = http:HTTP_1_1,
        secureSocket = {
            cert: {
                path: config:truststorePath,
                password: config:truststorePassword
            }
        }
    );

    json tokenResponse = check clientTokenEndpoint->post(
        "",
        {
            "grant_type": "organization_switch_cc",
            "scope": "SYSTEM",
            "token": accessToken,
            "switching_organization": subOrganizationId
        },
        {
            "Authorization": string `Basic ${utils:getBasicAuth()}`
        },
        mime:APPLICATION_FORM_URLENCODED
    );

    return <string> check tokenResponse.access_token;
}

// Change account recovery regex of the sub organization.
isolated function changeAccountRecoveryRegex(string subOrgAccessToken) returns json|error {

    http:Client changeAccountRecoveryRegexEndpoint = check new (
        config:apiServerEndpoint, 
        httpVersion = http:HTTP_1_1,
        secureSocket = {
            cert: {
                path: config:truststorePath,
                password: config:truststorePassword
            }
        }
    );

    json requestBody = {
        "operation": "UPDATE",
        "properties": [
            {
            "name": "Recovery.CallbackRegex",
            "value": ".*"
            }
        ]
    };

    json response =  check changeAccountRecoveryRegexEndpoint->patch(
        "/identity-governance/QWNjb3VudCBNYW5hZ2VtZW50/connectors/YWNjb3VudC1yZWNvdmVyeQ",
        requestBody,
        {
            "Authorization": string `Bearer ${subOrgAccessToken}`
        },
        mime:APPLICATION_JSON
    );
    return response;
}

// Get the admin role id.
isolated function getApplicationRoleId(string subOrgAccessToken) returns string|error {

    http:Client getAdminRoleIdEndpoint = check new (
        config:scimEndpoint, 
        httpVersion = http:HTTP_1_1,
        secureSocket = {
            cert: {
                path: config:truststorePath,
                password: config:truststorePassword
            }
        }
    );

    json adminRoleIdResponse = check getAdminRoleIdEndpoint->get(
        string `/v2/Roles?filter=displayName%20eq%20${config:applicationRoleName}`,
        {
            "Authorization": string `Bearer ${subOrgAccessToken}`
        }
    );

    json resources = check adminRoleIdResponse.Resources; 
    json[] resourcesArray = <json[]> resources;
    if (resourcesArray.length() > 0) {
        json adminRole = resourcesArray[0];
        json adminRoleId = check adminRole.id;
        return adminRoleId.toString();
    } else {
       return error ("Error while getting admin role id.");
    }
}

// Create a user in the sub organization. 
isolated function createUser(models:SalesforcePayload salesForcePayload, string adminRoleId, string subOrgAccessToken) 
    returns json|error {

    http:Client scimEndpoint = check new (
        config:scimEndpoint, 
        httpVersion = http:HTTP_1_1,
        secureSocket = {
            cert: {
                path: config:truststorePath,
                password: config:truststorePassword
            }
        }
    );

    json userCreation = {
        "method": "POST",
        "bulkId": "userCreation:1",
        "path": "/Users",
        "data": {
            "schemas": [
            "urn:ietf:params:scim:schemas:core:2.0:User",
            "urn:scim:wso2:schema"
            ],
            "name": {
                "familyName": salesForcePayload.lastName,
                "givenName": salesForcePayload.firstName
            },
            "userName": salesForcePayload.username,
            "emails": [
                {
                    "primary": true,
                    "value": salesForcePayload.email
                }
            ],
            "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User": {"askPassword": true}
        }
    };

    json roleAssignment = {  
        "method":"PATCH",
        "path": string `/v2/Roles/${adminRoleId}`,
        "data":{
            "Operations":[
                {
                    "op":"add",
                    "value": {
                        "users":[
                            {
                                "value": "bulkId:userCreation:1"
                            }
                        ]
                    }
                }
            ]
        }
    };

    json requestBody = {
        "schemas": [
            "urn:ietf:params:scim:api:messages:2.0:BulkRequest"
        ],
        "Operations": [
            userCreation,
            roleAssignment
        ]
    };

    json response =  check scimEndpoint->post(
        "/Bulk",
        requestBody,
        {
            "Authorization": string `Bearer ${subOrgAccessToken}`
        },
        mime:APPLICATION_JSON
    );
    return response;
}
