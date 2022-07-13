Include Ensemble

/// This class adds HTTP request logging
Class isc.ateam.fsub.bo.RestClientHTTP Extends HS.FHIRServer.RestClient.HTTP
{

Property parentHost As isc.ateam.fsub.bo.RESTHookOperation [ Private ];

Method setParentHost(parentHost As isc.ateam.fsub.bo.RESTHookOperation)
{
	set ..parentHost = parentHost
}

/// Overridden in order to log HTTP requests via $$$HSTRACE
Method InvokeRequest(pRequest As %RegisteredObject, pRequestMethod As %String, pRequestPath As %String, pQueryString As %String) As %Net.HttpResponse
{
	#dim sc As %Status = $$$OK
	#dim return As %Net.HttpResponse = ""
	try
	{
		set return = ##super(pRequest, pRequestMethod, pRequestPath, pQueryString)
	}
	catch ex
	{
		set sc = ex.AsStatus()
	}
	
	// log before throwing
	if $isObject(..parentHost) do ..parentHost.hsTraceHttpRequest("HTTP request info", "##class("_$$$CurrentClass_")."_$$$CurrentMethod_"()", ..%HttpRequest, pRequestMethod, sc)
	
	$$$ThrowOnError(sc)
	
	quit return
}

}

