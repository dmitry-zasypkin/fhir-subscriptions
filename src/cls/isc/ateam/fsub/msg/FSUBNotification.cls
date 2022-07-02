Class isc.ateam.fsub.msg.FSUBNotification Extends (%Persistent, Ens.Request)
{

Property subscriptionId As %String;

Property subscriptionStream As %Stream.GlobalCharacter;

Property subscriptionJson As %DynamicObject(XMLPROJECTION = "none") [ Transient ];

Property subscriptionCriteria As %String(MAXLEN = "");

Property resourceType As %String;

Property matchingResources As list Of isc.ateam.fsub.msg.OneErrorSerial(XMLITEMNAME = "resource");

Storage Default
{
<Data name="FSUBNotificationDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>subscriptionId</Value>
</Value>
<Value name="3">
<Value>subscriptionStream</Value>
</Value>
<Value name="4">
<Value>subscriptionCriteria</Value>
</Value>
<Value name="5">
<Value>resourceType</Value>
</Value>
<Value name="6">
<Value>matchingResources</Value>
</Value>
</Data>
<DataLocation>^isc.ateamA8F4.FSUBNotific4606D</DataLocation>
<DefaultData>FSUBNotificationDefaultData</DefaultData>
<IdLocation>^isc.ateamA8F4.FSUBNotific4606D</IdLocation>
<IndexLocation>^isc.ateamA8F4.FSUBNotific4606I</IndexLocation>
<StreamLocation>^isc.ateamA8F4.FSUBNotific4606S</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}

