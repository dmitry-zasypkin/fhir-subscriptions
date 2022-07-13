Include HS.FHIRServer

/// REST Handler that impersonates a remote service that receives "REST Hook" notifications.
/// See https://www.hl7.org/fhir/r4/subscription.html#2.46.7.1
/// 
/// Incoming requests are logged to ^FSLOG global provided ^FSLogChannel has been configured
///   see https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXFHIR_server_debugMaintain#HXFHIR_server_debug_log_internal for details
/// 
Class isc.ateam.fsub.mock.DummyRESTHookHandler Extends %CSP.REST
{

XData UrlMap
{
<Routes>
	<Route Url="/no-payload" Method="POST" Call="noPayload"/>
	<Route Url="/with-payload/(.*)" Method="PUT" Call="withPayload"/>
</Routes>
}

Parameter standardHttpHEADERS = {$lb("ACCEPT_ENCODING", "CONTENT_LENGTH", "HOST", "REFERER", "USER_AGENT", "ACCEPT")};

ClassMethod noPayload() As %Status
{
	do ..logRequest()
	quit $$$OK
}

ClassMethod withPayload(requestPath As %String) As %Status
{
	do ..logRequest()
	
	// output some headers that are expected from Update operation
	#dim %response As %CSP.Response
	do %response.SetHeader("CONTENT-LOCATION", "http://tempuri.org/fhir/" _ requestPath _ "/_history/1")
	do %response.SetHeader("ETAG", "W/""1""")
	do %response.SetHeader("LOCATION", "http://tempuri.org/fhir/" _ requestPath _ "/_history/1")
	set %response.Expires = 0

	quit $$$OK
}

ClassMethod logRequest() [ Private ]
{
	#dim %request As %CSP.Request
	
	$$$FSLog(">>>>>> " _ $$$URLDECODE($get(%request.CgiEnvs("REQUEST_URI"))))
	
	// log custom headers
	#dim key As %String = $order(%request.CgiEnvs(""))
	while (key '= "")
	{
		if (key [ "HTTP_") 
			&& ($piece(key, "HTTP_", 1) = "") 
			&& (0 = $listFind(..#standardHttpHEADERS, $piece(key, "HTTP_", 2, *)))
		{
			$$$FSLog(">>>>>> " _ $piece(key, "HTTP_", 2, *) _ ": " _ %request.CgiEnvs(key))
		}
		
		set key = $order(%request.CgiEnvs(key))
	}
	
	// log request body
	if $isObject(%request.Content)
	{
		do ..logRequestContent(%request.Content)
	}
	else
	{
		// MIME
		#dim index As %Integer = %request.NextMimeData("")
		while (index '= "")
		{
			do ..logRequestContent(%request.GetMimeData(index))
			set index = %request.NextMimeData(index)
		}
	}
}

ClassMethod logRequestContent(stream As %Stream.Object) [ Private ]
{
	#dim content As %String = stream.Read($$$MaxLocalLength)
	$$$FSLog($zstrip($translate(content, $c(13,10,9), "   "), "<=>W"))
}

}

