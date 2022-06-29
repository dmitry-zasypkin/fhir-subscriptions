Class isc.ateam.fsub.msg.FHIRErrorNotification Extends isc.ateam.fsub.msg.FHIRRequest
{

Property errors As list Of isc.ateam.fsub.msg.OneErrorSerial(XMLITEMNAME = "error");

Storage Default
{
<Data name="FHIRErrorNotificationDefaultData">
<Subscript>"FHIRErrorNotification"</Subscript>
<Value name="1">
<Value>errors</Value>
</Value>
</Data>
<DefaultData>FHIRErrorNotificationDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}

