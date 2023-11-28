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

import ballerina/log;
import ballerinax/trigger.salesforce as sfdc;
import wso2_salesforce_integration.config;
import wso2_salesforce_integration.models;
import wso2_salesforce_integration.api;

sfdc:ListenerConfig configuration = {
    username: config:SFUsername,
    password: config:SFPassword + config:SFSecurityToken,
    channelName: "/data/AccountChangeEvent"
};

listener sfdc:Listener sfListener = new (configuration);
service sfdc:RecordService on sfListener {
    isolated remote function onCreate(sfdc:EventData payload) returns error? {
        log:printInfo("DEBUG: SF status change payload: " + payload.toString());
        map<json> changedData = payload.changedData;

        string email = changedData.get(config:SFMappingEmail).toString();
        string orgName = changedData.get(config:SFMappingOrgName).toString();
        string username = changedData.get(config:SFMappingUsername).toString();
        string firstName = changedData.get(config:SFMappingFirstName).toString();
        string lastName = changedData.get(config:SFMappingLastName).toString();

        models:SalesforcePayload salesforcePayload = {
            username: username,
            email: email,
            orgName: orgName,
            firstName: firstName,
            lastName: lastName
        };

        json response = check api:createSubOrganizationAdmin(salesforcePayload);
        log:printInfo("INFO: Response :" + response.toString());
        return;
    }

    isolated remote function onUpdate(sfdc:EventData payload) returns error? {
        // Not implemented.
        return;
    }

    isolated remote function onDelete(sfdc:EventData payload) returns error? {
        // Not implemented.
        return;
    }

    isolated remote function onRestore(sfdc:EventData payload) returns error? {
        // Not implemented.
        return;
    }
}
