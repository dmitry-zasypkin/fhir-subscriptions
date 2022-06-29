Class isc.ateam.fsub.msg.FHIRRequest Extends (%Persistent, Ens.Request)
{

Property fhirRequest As HS.FHIRServer.API.Data.Request;

Property operationName As %String;

Property targetType As %String;

Property targetId As %String(MAXLEN = "");

Property httpStatus As %String(MAXLEN = 256);

Property fhirRequestBody As %Stream.GlobalCharacter;

Property fhirResponseBody As %Stream.GlobalCharacter;

Property info As %String(MAXLEN = "");

Method %OnNew(fhirRequest As HS.FHIRServer.API.Data.Request, fhirResponse As HS.FHIRServer.API.Data.Response = "", requestStream As %Stream.Object = "", info As %String = "") As %Status
{
	set ..fhirRequest = fhirRequest
	set ..operationName = fhirRequest.OperationName
	set ..targetType = fhirRequest.Type
	set ..targetId = fhirRequest.Id
	set ..info = info
	
	if $isObject(requestStream) do ..fhirRequestBody.CopyFrom(requestStream)
	
	if $isObject(fhirResponse)
	{
		set ..httpStatus = fhirResponse.Status
		if $isObject(fhirResponse.Json) do fhirResponse.Json.%ToJSON(..fhirResponseBody)
	}

	quit $$$OK
}

Storage Default
{
<Data name="FHIRRequestDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>fhirRequest</Value>
</Value>
<Value name="3">
<Value>operationName</Value>
</Value>
<Value name="4">
<Value>targetType</Value>
</Value>
<Value name="5">
<Value>targetId</Value>
</Value>
<Value name="6">
<Value>httpStatus</Value>
</Value>
<Value name="7">
<Value>fhirRequestBody</Value>
</Value>
<Value name="8">
<Value>fhirResponseBody</Value>
</Value>
<Value name="9">
<Value>info</Value>
</Value>
</Data>
<DataLocation>^isc.ateam.fsubA8F4.FHIRRequestD</DataLocation>
<DefaultData>FHIRRequestDefaultData</DefaultData>
<IdLocation>^isc.ateam.fsubA8F4.FHIRRequestD</IdLocation>
<IndexLocation>^isc.ateam.fsubA8F4.FHIRRequestI</IndexLocation>
<StreamLocation>^isc.ateam.fsubA8F4.FHIRRequestS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}

