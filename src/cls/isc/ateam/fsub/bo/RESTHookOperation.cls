/// This operation sends "REST Hook" notifications to subscribers - see https://www.hl7.org/fhir/r4/subscription.html#2.46.7.1
/// It takes a FHIRServer Interop request and invokes an HTTP request.
/// Pieces of code have been borrowed from HS.FHIRServer.Interop.HTTPOperation (I4H 2022.2).
Class isc.ateam.fsub.bo.RESTHookOperation Extends HS.FHIRServer.Interop.HTTPOperation
{

/// Enable this setting to have the operation throw an exception when it receives 5xx HTTP status code.
/// This will result in retries if "Reply Code Actions" are configured.
Property Throw5xxStatusErrors As %Boolean [ InitialExpression = {$$$YES} ];

Parameter SETTINGS = "Throw5xxStatusErrors:Basic";

Parameter httpClientCLASS = "isc.ateam.fsub.bo.RestClientHTTP";

/// This method handles both types of REST Hook notifications (with/without payload) described in https://www.hl7.org/fhir/r4/subscription.html#2.46.7.1
/// Pieces of code have been borrowed from HS.FHIRServer.Interop.HTTPOperation (I4H 2022.2).
Method DispatchRequest(pInteropRequest As HS.FHIRServer.Interop.Request, Output pInteropResponse As HS.FHIRServer.Interop.Response) As %Status
{
	#dim httpClient As isc.ateam.fsub.bo.RestClientHTTP = ""
	#dim clientResponse As HS.FHIRServer.API.Data.RestClient.Response = ""
	
	#dim sc As %Status = $$$OK
	try
	{
		$$$ThrowOnError(pInteropRequest.NewResponse(.pInteropResponse))
		
		#dim fhirRequest As HS.FHIRServer.API.Data.Request = pInteropRequest.Request
		
		// ServiceName is a setting on this host, but can be overridden by request AdditionalInfo "ServiceName" value.
		#dim serviceName As %String = fhirRequest.AdditionalInfo.GetAt("ServiceName")
		if (serviceName = "")
		{
			set serviceName = ..ServiceName
			if (serviceName = "")
			{
				set sc = $$$ERROR($$$HSFHIRErrServiceNameNotSpecified)
				quit
			}
		}
		
		#dim httpService As HS.Registry.Service.HTTP = ##class(HS.Registry.Service.Abstract).EndPointForNameType(serviceName, "HTTP")
		if '$isObject(httpService)
		{
			set sc = $$$ERROR($$$HSFHIRErrInvalidHTTPServiceSpecified, serviceName)
			quit
		}
		
		#dim requestMethod As %String = $zcvt(fhirRequest.RequestMethod, "U")
		#dim prefer As %String = fhirRequest.Prefer
		#dim sessionId As %String = fhirRequest.AdditionalInfo.GetAt("SessionId")
		#dim oauthClientName As %String = fhirRequest.AdditionalInfo.GetAt("USER:OAuthClient")
		#dim oauthToken As %String = fhirRequest.AdditionalInfo.GetAt("USER:OAuthToken")
		#dim oauthSendType As %String = fhirRequest.AdditionalInfo.GetAt("OAuthSendType")
		
		// Create the HTTP client object anew on each request, as instantiation
		// information could change between requests.
		set httpClient = $classmethod(..#httpClientCLASS, "CreateInstance", serviceName, prefer, sessionId, oauthClientName, oauthToken, oauthSendType)
		do httpClient.setParentHost($this)
		
				
		if (pInteropRequest.QuickStreamId '= "")
		{
			if (requestMethod '= "PUT")
			{
				set sc = $$$ERROR($$$GeneralError, "Unexpected HTTP Method: " _ requestMethod)
				quit
			}
			
			#dim path As %String = $zstrip(fhirRequest.RequestPath, "<>", "/")
			if ($length(path, "/") '= 2)
			{
				$$$ThrowError($$$HSFHIRErrInvalidRequestPath, fhirRequest.RequestPath)
			}
			
			#dim resourceType As %String = $piece(path, "/", 1)
			#dim resourceId As %String = $piece(path, "/", 2)
			
			#dim quickStreamIn As HS.SDA3.QuickStream = ##class(HS.SDA3.QuickStream).%OpenId(pInteropRequest.QuickStreamId, .sc)
			$$$ThrowOnError(sc)
			
			$$$HSTRACE("Request QuickStream", "quickStreamIn", quickStreamIn)
			
			$$$ThrowOnError(quickStreamIn.Rewind())
			
			// Set the Content-Type header. Required charset for FHIR content is UTF-8.
			do httpClient.SetRequestFormat(fhirRequest.RequestFormatCode, "UTF-8")
			
			// Set the Accept header. Charset is optional for Accept, leave it off.
			do httpClient.SetResponseFormat(fhirRequest.ResponseFormatCode, "")
			
			set clientResponse = httpClient.Update(resourceType, resourceId, quickStreamIn)
		}
		else
		{
			if (requestMethod '= "POST")
			{
				set sc = $$$ERROR($$$GeneralError, "Unexpected HTTP Method: " _ requestMethod)
				quit
			}
			
			// we expect additional HTTP headers in pInteropRequest.Request.AdditionalInfo array entries 
			//  that have keys starting with the word "HEADER:"
			kill headers
			do ..extractHttpHeaders(pInteropRequest.Request.AdditionalInfo, .headers)
			
			// POST empty request
			#dim httpRequest As %Net.HttpRequest = httpClient.MakeRequest("POST", "", "", "", .headers)
			set sc = httpRequest.Send("POST", httpService.URL)
			do ..hsTraceHttpRequest("No payload notification", $$$CurrentMethod, httpRequest, "POST", sc)
			if $$$ISERR(sc) quit
			
			try
			{
				set clientResponse = httpClient.MakeClientResponseFromResponse(httpRequest.HttpResponse)
			}
			catch innderEx
			{
				// ignore exception since the response is not really important, and no need to retry in case of response handling errors
				$$$LOGSTATUS(innderEx.AsStatus())
				set clientResponse = ""
			}
		}

		if '$isObject(clientResponse) quit

		// handle the response
		// ignore exceptions since the response is not really important, and no need to retry in case of response handling errors
		try
		{
			#dim apiResponse As HS.FHIRServer.API.Data.Response = ##class(HS.FHIRServer.API.Data.Response).%New()
			set apiResponse.ETag = clientResponse.ETag
			set apiResponse.Id = clientResponse.Id
			set apiResponse.IsPrettyOut = clientResponse.IsPrettyOut
			set apiResponse.LastModified = clientResponse.LastModified
			set apiResponse.Location = clientResponse.Location
			set apiResponse.Status = clientResponse.Status
			set apiResponse.VId = clientResponse.VId
						
			// API response ResponseFormatCode holds a simple code such as $$$FHIRContentCodeJSON or $$$FHIRContentCodeXML.
			if (clientResponse.ResponseFormat [ "application/fhir+json")
			{
				set apiResponse.ResponseFormatCode = $$$FHIRContentCodeJSON
			}
			elseif (clientResponse.ResponseFormat [ "application/fhir+xml")
			{
				set apiResponse.ResponseFormatCode = $$$FHIRContentCodeXML
			}
			
			set pInteropResponse.Response = apiResponse
			set pInteropResponse.CharSet = "UTF-8"
			set pInteropResponse.ContentType = clientResponse.ResponseFormat
			
			if $isObject(clientResponse.Payload)
			{
				#dim quickStreamOut As HS.SDA3.QuickStream = ##class(HS.SDA3.QuickStream).%New()
				set pInteropResponse.QuickStreamId = quickStreamOut.%Id()
				$$$ThrowOnError(quickStreamOut.CopyFrom(clientResponse.Payload))
				$$$HSTRACE("Response QuickStream", "quickStreamOut", quickStreamOut)
				$$$ThrowOnError(quickStreamOut.Rewind())
			}
		}
		catch innerEx
		{
			set sc = innerEx.AsStatus()
		}
		
		if $$$ISERR(sc)
		{
			$$$LOGSTATUS(sc)
			
			// ignore exceptions since the response is not really important, and no need to retry in case of response handling errors
			set sc = $$$OK
		}
	}
	catch ex
	{
		set sc = ex.AsStatus()
	}
	
	// clean up
	if $isObject(httpClient) do httpClient.setParentHost("")
	
	// throw fatal exception, e.g. if unable to establish TCP connection
	$$$QuitOnError(sc)
	
	
	if ..Throw5xxStatusErrors && $isObject(clientResponse)
	{
		// throw exception in case of 5xx HTTP Status Code in order to trigger retries if "Reply Code Actions" setting is configured
		if ($extract(clientResponse.Status, 1, 1) = "5")
		{
			set sc = $$$ERROR($$$GeneralError, clientResponse.Status)
		}
	}
	
	quit sc
}

/// We expect additional HTTP headers in AdditionalInfo array entries that have keys starting with "HEADER:"
ClassMethod extractHttpHeaders(additionalInfoArray As %ArrayOfObjects, ByRef headers) [ Private ]
{
	kill headers
	#dim key As %String = ""
	for
	{
		#dim value As %String = additionalInfoArray.GetNext(.key)
		if (key = "") quit

		if (key [ "HEADER:") && ($piece(key, "HEADER:", 1) = "") && ($piece(key, "HEADER:", 2, *) '= "")
		{
			set headers($zstrip($piece(key, "HEADER:", 2, *), "<>W")) = value
		}
	} // for
}

/// Log full request URL, HTTP method, error status code (if any) and response status line (if there was a response)
Method hsTraceHttpRequest(comment As %String, method As %String, httpRequest As %Net.HttpRequest, httpMethod As %String, sc As %Status)
{
	try
	{
		#dim fullURL As %String = $case(httpRequest.Https, $$$YES:"https", :"http") _ "://" _ httpRequest.Server _ ":" _ httpRequest.Port _ "/" _ httpRequest.Location
		#dim responseStatusLine As %String = $case($isObject(httpRequest.HttpResponse), $$$YES:httpRequest.HttpResponse.StatusLine, :"")
		
		$$$HSTRACE(comment, "Method,URL,HTTP Method,%Status,HTTP Status Line", method, fullURL, httpMethod, $System.Status.GetErrorText(sc), responseStatusLine)
	}
	catch ex
	{
		$$$LOGSTATUS(ex.AsStatus())
	}
}

}

