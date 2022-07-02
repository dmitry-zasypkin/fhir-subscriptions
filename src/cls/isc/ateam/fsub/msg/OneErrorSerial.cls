Class isc.ateam.fsub.msg.OneErrorSerial Extends (%SerialObject, %XML.Adaptor)
{

Parameter XMLIGNORENULL = "inputonly";

Property resourceType As %String;

Property resourceId As %String;

Property resourceStream As %Stream.GlobalCharacter;

Property resourceJson As %DynamicObject(XMLPROJECTION = "none") [ Transient ];

Property httpMethod As %String;

Property errorCodes As %String;

Property errorText As %String(MAXLEN = "");

Property status As %Status;

Property stack As list Of %String(MAXLEN = "");

Storage Default
{
<Data name="OneErrorSerialState">
<Value name="1">
<Value>resourceType</Value>
</Value>
<Value name="2">
<Value>resourceId</Value>
</Value>
<Value name="3">
<Value>resourceStream</Value>
</Value>
<Value name="4">
<Value>httpMethod</Value>
</Value>
<Value name="5">
<Value>errorCodes</Value>
</Value>
<Value name="6">
<Value>errorText</Value>
</Value>
<Value name="7">
<Value>status</Value>
</Value>
<Value name="8">
<Value>stack</Value>
</Value>
</Data>
<State>OneErrorSerialState</State>
<StreamLocation>^isc.ateam.fA8F4.OneErrorSerialS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}

