// Azure Security Policy for ISAPI Migration
// This policy ensures App Service instances follow security best practices
targetScope = 'subscription'

param policyName string = 'ISAPI-Migration-Security-Policy'
param displayName string = 'Delphi ISAPI Migration Security Requirements'
param description string = 'Security policy for migrated Delphi ISAPI applications'

// Policy definition for App Service security requirements
resource securityPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: policyName
  properties: {
    displayName: displayName
    description: description
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'App Service'
      purpose: 'ISAPI Migration Security'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policy'
        }
        allowedValues: [
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'AuditIfNotExists'
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Web/sites'
          }
          {
            field: 'tags[purpose]'
            equals: 'ISAPI Migration'
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.Web/sites/config'
          name: 'web'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Web/sites/config/httpsOnly'
                equals: true
              }
              {
                field: 'Microsoft.Web/sites/config/use32BitWorkerProcess'
                equals: false
              }
              {
                field: 'Microsoft.Web/sites/config/alwaysOn'
                equals: true
              }
            ]
          }
        }
      }
    }
  }
}

output policyId string = securityPolicy.id
