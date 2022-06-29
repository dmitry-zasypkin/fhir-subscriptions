Class isc.ateam.fsub.FHIRErrorNotification Extends isc.ateam.fsub.msg.FHIRRequest
{

Property errorCodes As %String;

Property errorText As %String(MAXLEN = "");

Property status As %Status;

Property stack As list Of %String(MAXLEN = "");

Storage Default
{
<Data name="FHIRErrorNotificationDefaultData">
<Subscript>"FHIRErrorNotification"</Subscript>
<Value name="1">
<Value>errorCodes</Value>
</Value>
<Value name="2">
<Value>errorText</Value>
</Value>
<Value name="3">
<Value>status</Value>
</Value>
<Value name="4">
<Value>stack</Value>
</Value>
</Data>
<DefaultData>FHIRErrorNotificationDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}

