Include HS.FHIRMeta

Class isc.ateam.fsub.FSUBRouterProcess Extends Ens.BusinessProcess
{

/// Production setting that specifies FHIR Endpoint path
Parameter fhirEndpointSETTING = "FHIREndpoint";

Method OnRequest(pRequest As isc.ateam.fsub.msg.FSUBNotification, Output pResponse As Ens.Response) As %Status
{
	// FHIRErrorNotification requests are initiated for logging purposes only
	if pRequest.%Extends(##class(isc.ateam.fsub.msg.FHIRErrorNotification).%ClassName(1))
	{
		#dim errorNotification As isc.ateam.fsub.msg.FHIRErrorNotification = pRequest
		#dim errorStatus As %Status = ""
		for i = 1:1:errorNotification.errors.Count()
		{
			#dim errorItem = errorNotification.errors.GetAt(i)
			set errorStatus = $case(errorStatus, "":errorItem.status, :$$$ADDSC(errorStatus, errorItem.status))
		}
		
		// log Subscription processing errors to Event Log
		quit errorStatus
	}
	

	#dim sc As %Status = $$$OK
	try
	{
		do ..handleNotificationRequest(pRequest)
	}
	catch ex
	{
		set sc = ex.AsStatus()
	}
	
	quit sc
}

/// Async responses from notification targets
Method OnResponse(request As %Library.Persistent, ByRef response As %Library.Persistent, callrequest As HS.FHIRServer.Interop.Request, callresponse As HS.FHIRServer.Interop.Response, pCompletionKey As %String) As %Status
{
	do ..cleanUpQS()
	quit $$$OK
}

Method OnError(request As %Library.Persistent, ByRef response As %Library.Persistent, callrequest As %Library.Persistent, pErrorStatus As %Status, pCompletionKey As %String) As %Status
{
	do ..cleanUpQS()
	quit pErrorStatus
}

/// Clean up QuickStream in request and response
ClassMethod cleanUpQS(callrequest As HS.FHIRServer.Interop.Request, callresponse As HS.FHIRServer.Interop.Response) [ Private ]
{
	try
	{
		if $isObject($get(callrequest)) && (callrequest.QuickStreamId '= "")
		{
			#dim qs As HS.SDA3.QuickStream = ##class(HS.SDA3.QuickStream).%OpenId(callrequest.QuickStreamId)
			if $isObject(qs) do qs.Clear()
		}
		
		if $isObject($get(callresponse)) && (callresponse.QuickStreamId '= "")
		{
			#dim qs2 As HS.SDA3.QuickStream = ##class(HS.SDA3.QuickStream).%OpenId(callresponse.QuickStreamId)
			if $isObject(qs2) do qs2.Clear()
		}
	}
	catch ex
	{
		$$$LOGSTATUS(ex.AsStatus())
	}
}

Method handleNotificationRequest(request As isc.ateam.fsub.msg.FSUBNotification) [ Private ]
{
	if (request.subscriptionStream.Size = 0) $$$ThrowError($$$GeneralError, "Empty subscriptionStream")
	set request.subscriptionJson = ##class(%DynamicObject).%FromJSON(request.subscriptionStream)
	
	// as of now, "REST Hook" is the only supported channel type 
	if (request.subscriptionJson.channel.type '= "rest-hook")
	{
		$$$ThrowError($$$GeneralError, "Channel type not supported: " _ request.subscriptionJson.channel.type)
	}
	
	#dim payloadMimeType As %String = request.subscriptionJson.channel.payload
	if (payloadMimeType '= "") && (payloadMimeType '= "application/fhir+json") && (payloadMimeType '= "application/fhir+xml")
	{
		$$$ThrowError($$$GeneralError, "Unsupported MIME type for payload: " _ payloadMimeType)
	}
	
	#dim endpoint As %String = request.subscriptionJson.channel.endpoint
	#dim headerArray As %DynamicArray = request.subscriptionJson.channel.header
	
	// search for a HTTP Service Registry entry that has the full endpoint URL in its Alias field
	// note that an entry can have multiple aliases, e.g. IP address or domain name based URLs
	#dim serviceEntry As HS.Registry.Service.HTTP = ##class(HS.Registry.Service.Abstract).EndPointForNameType(endpoint, "HTTP")
	if '$isObject(serviceEntry) $$$ThrowError($$$GeneralError, "Endpoint not found in the Service Registry: " _ endpoint)
	
	// search for a business operation with ServiceName=<name of the Service Registry entry we've just found>
	#dim operation As Ens.Config.Item = ..findConfigItemBySettingValue("ServiceName", serviceEntry.Name, $$$eHostTypeOperation)
	if '$isObject(operation) $$$ThrowError($$$GeneralError, "Cannot find Business Operation with ServiceName=""" _ serviceEntry.Name _ """")
	
	
	if (payloadMimeType = "")
	{
		// REST request without payload, see https://www.hl7.org/fhir/r4/subscription.html#2.46.7.1
		#dim noPayloadMessage As HS.FHIRServer.Interop.Request = ##class(HS.FHIRServer.Interop.Request).%New()
		set noPayloadMessage.Request.RequestMethod = "POST"
		
		// add custom headers to the request's AdditionalInfo array
		if (headerArray '= "") do ..addCustomHeadersToAdditionalInfo(headerArray, noPayloadMessage.Request)
		
		// NB: send only ONE notification, even if there are multiple resources matching the current Subscription
		// see https://www.hl7.org/fhir/r4/subscription.html#2.46.7.1
		$$$ThrowOnError(..SendRequestAsync(operation.Name, noPayloadMessage,,, "FSUB No Payload Notification"))
	}
	else
	{
		#dim schema As HS.FHIRServer.Schema = "" // we will need schema when transforming JSON to XML
		
		// get the schema reference in case of XML payload
		if (payloadMimeType = "application/fhir+xml")
		{
			#dim sc As %Status = $$$OK
			#dim fhirEndpoint As %String = ##class(Ens.Director).GetCurrProductionSettingValue(..#fhirEndpointSETTING, .sc)
			$$$ThrowOnError(sc)

			// get Interactions Strategy
			#dim strategy As HS.FHIRServer.API.InteractionsStrategy = ##class(HS.FHIRServer.API.InteractionsStrategy).GetStrategyForEndpoint(fhirEndpoint)
			
			set schema = strategy.schema
		}
		
		// NB: the following CreateInstance() method expects the current production to be registered in the Installer Wizard for the current namespace (see HS.Util.Installer.ConfigItem class)
		//     hence it will throw an error if one changes to a different production after initial namespace setup
		#dim clientObj As HS.FHIRServer.RestClient.Interop = ##class(HS.FHIRServer.RestClient.Interop).CreateInstance(serviceEntry.Name,,,,,, operation.Name, $this)
		do clientObj.SetRequestFormat($case(payloadMimeType, "application/fhir+xml":"XML", :"JSON"))
		do clientObj.SetResponseFormat("JSON")
		
		// iterate over the matching resources
		for i = 1:1:request.matchingResources.Count()
		{
			#dim resType As %String = request.matchingResources.GetAt(i).resourceType
			#dim resId As %String = request.matchingResources.GetAt(i).resourceId
			#dim payload As %Stream.Object = request.matchingResources.GetAt(i).resourceStream
			
			if (payloadMimeType = "application/fhir+xml")
			{
				// transform resource to XML
				#dim xmlPayload As %Stream.Object = ""
				do ##class(HS.FHIRServer.Util.JSONToXML).JSONToXML(payload, .xmlPayload, schema)
				set payload = xmlPayload
			}
			
			#dim message As HS.FHIRServer.Interop.Request = clientObj.MakeRequest("PUT", payload,	"/" _ resType _ "/" _ resId, "")
			do message.Request.AdditionalInfo.RemoveAt("ServiceName")  // we don't actually need ServiceName to be passed in requests
			
			// add custom headers to the request's AdditionalInfo array
			if (headerArray '= "") do ..addCustomHeadersToAdditionalInfo(headerArray, message.Request)
			
			// send *async* request to the operation (async requests are not supported by HS.FHIRServer.RestClient.Interop as of 2022.1, so calling SendRequestAsync "manually")
			$$$ThrowOnError(..SendRequestAsync(operation.Name, message,,, "FSUB Notification With Payload"))

		} // for
	}
}

/// Add custom headers to the request's AdditionalInfo array.
ClassMethod addCustomHeadersToAdditionalInfo(headerArray As %DynamicArray, request As HS.FHIRServer.API.Data.Request) [ Private ]
{
	#dim iter As %Iterator.Object = headerArray.%GetIterator()
	#dim entry As %String
	#dim keyPrefix As %String = "HEADER:"
	while iter.%GetNext(.key, .entry)
	{
		do request.AdditionalInfo.SetAt($zstrip($piece(entry, ":", 2), "<>W"), keyPrefix _ $zstrip($piece(entry, ":", 1), "<>W"))
	}
}

/// Find a business host by setting's name/value pair.
/// <var>businessType</var> can be $$$eHostTypeService, $$$eHostTypeProcess or $$$eHostTypeOperation.
/// Empty <var>businessType</var> means that type does not matter.
/// If <var>enabledOnly</var> is 1 then search enabled hosts only.
ClassMethod findConfigItemBySettingValue(settingName As %String, settingValue As %String, businessType As %String(VALUELIST=",1,2,3") = "", enabledOnly As %Boolean = {$$$NO}) As Ens.Config.Item
{
	#dim prod As Ens.Config.Production = ..getCurrentProduction()
	if '$isObject(prod) quit ""

	// loop through production elements
	#dim result As Ens.Config.Item = ""
	for i = 1:1:prod.Items.Count()
	{
		#dim item As Ens.Config.Item = prod.Items.GetAt(i)

		if '$isObject(item)
				|| ((businessType '= "") && (item.BusinessType() '= businessType))
				|| (enabledOnly && 'item.Enabled)
		{
			continue
		}
		
		// loop through settings
		do item.PopulateModifiedSettings()
		#dim ind As %String = ""
		for
		{
			#dim setting = item.ModifiedSettings.GetNext(.ind)
			if (ind = "") quit

			if (setting.Name = settingName)
			{
				if ($zstrip(setting.Value, "<>W") = $zstrip(settingValue, "<>W")) set result = item
				quit
			}
		} // for

		if $isObject(result) quit
	} // for
	
	quit result
}

ClassMethod getCurrentProduction() As Ens.Config.Production
{
	#dim prodName As %String
	if '##class(Ens.Director).IsProductionRunning(.prodName) quit ""
	
	#dim sc As %Status
	#dim prod As Ens.Config.Production = ##class(Ens.Config.Production).%OpenId(prodName,, .sc)
	$$$ThrowOnError(sc)  // highly unlikely
	
	quit prod
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}

