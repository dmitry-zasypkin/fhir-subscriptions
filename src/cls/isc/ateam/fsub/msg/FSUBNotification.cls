Class isc.ateam.fsub.msg.FSUBNotification Extends (%Persistent, Ens.Request)
{

Property resourceType As %String;

Property resourceId As %String;

Property httpMethod As %String;

Property resourceStream As %Stream.GlobalCharacter;

Property resourceJson As %DynamicObject(XMLPROJECTION = "none") [ Transient ];

Property subscription As list Of %Stream.GlobalCharacter;

Property subscriptionJsonArray As %DynamicArray(XMLPROJECTION = "none") [ Transient ];

Storage Default
{
<Data name="FSUBNotificationDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>resourceType</Value>
</Value>
<Value name="3">
<Value>resourceId</Value>
</Value>
<Value name="4">
<Value>httpMethod</Value>
</Value>
<Value name="5">
<Value>resourceStream</Value>
</Value>
<Value name="6">
<Value>subscription</Value>
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

