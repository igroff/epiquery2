# POST /services/Soap/u/33.0
+ Response 200 (text/xml)

        <?xml version="1.0" encoding="utf-8"?>
        <soapenv:Envelope xmlns:soapenv="<a rel="nofollow" class="external free" href="http://schemas.xmlsoap.org/soap/envelope/">http://schemas.xmlsoap.org/soap/envelope/</a>"
        xmlns="urn:enterprise.soap.sforce.com"
        xmlns:xsi="<a rel="nofollow" class="external free" href="http://www.w3.org/2001/XMLSchema-instance">http://www.w3.org/2001/XMLSchema-instance</a>">
        <soapenv:Body>
            <loginResponse>
                <result>
                <passwordExpired>false</passwordExpired>
                <serverUrl>http://sfdc/services/Soap/c/10.0</serverUrl>
                <sessionId>QwWsHJyTPW.1pd0_jXlNKOSU</sessionId>
                <userId>005D0000000nVYVIA2</userId>
                <userInfo>
                    <accessibilityMode>false</accessibilityMode>
                    <currencySymbol>$</currencySymbol>
                    <organizationId>00DD0000000EFW9MAO</organizationId>
                    <organizationMultiCurrency>false</organizationMultiCurrency>
                    <organizationName>danorg</organizationName>
                    <profileId>00eD0000000v3qmIAA</profileId>
                    <roleId xsi:nil="true"/>
                    <userDefaultCurrencyIsoCode xsi:nil="true"/>
                    <userEmail>user@domain.com</userEmail>
                    <userFullName>Joe User</userFullName>
                    <userId>005D0000000nVQVIA2</userId>
                    <userLanguage>en_US</userLanguage>
                    <userLocale>en_US</userLocale>
                    <userName>user@domain.com</userName>
                    <userTimeZone>America/Los_Angeles</userTimeZone>
                    <userType>Standard</userType>
                    <userUiSkin>Theme2</userUiSkin>
                </userInfo>
                </result>
            </loginResponse>
        </soapenv:Body>
        </soapenv:Envelope>

# GET /services/data/v33.0/query?q=SELECT%0A%20%20Subscription_Id__c%2C%0A%20%20Start_Date__c%2C%0A%20%20Expiry_Date__c%2C%0A%20%20IsUsageBased__c%2C%0A%20%20Subscription_Revenue_Type__c%2C%0A%20%20Subscription_Type__c%0AFROM%20Subscription__c%0AWHERE%20Id%20%3D%20%27a0AU0000019hqdGMAQ%27%0A
+ Response 200 (application/json)

        {
            "done" : true,
            "length" : 1,
            "records" : 
            [ 
                {  
                    "attributes" : 
                    {    
                        "type" : "Subscription__c",    
                        "url" : "/services/data/version/sobjects/Subscription__c/a0AU0000019hqdGMAQ"  
                    },  
                    "Subscription_Id__c": "SUB-905822",
                    "Start_Date__c": "2015-08-01",
                    "Expiry_Date__c": "2016-01-31",
                    "IsUsageBased__c": false,
                    "Subscription_Revenue_Type__c": "Non-Unit Based",
                    "Subscription_Type__c": "OSP"                
                }
            ]
        }