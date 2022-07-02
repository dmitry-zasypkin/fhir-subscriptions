/// 
Class isc.ateam.fsub.FSUBRouterProcessRoutingRule Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "EnsLib.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="EnsLib.MsgRouter.RoutingEngine" production="isc.ateam.fsub.FSUBProduction">
<ruleSet name="" effectiveBegin="" effectiveEnd="">
<rule name="rule1">
<constraint name="msgClass" value="isc.ateam.fsub.msg.FSUBNotification"></constraint>
<when condition="1=1">
<assign property="Document.subscriptionJson" value="FromJSON(Document.subscriptionStream)"></assign>
<trace value='"ResourceType=" _ Document.resourceType_"; SubscriptionId="_Document.subscriptionId_"; Criteria="_Document.subscriptionCriteria'></trace>
<trace value='"Endpoint: "_GetFHIRPathOne(Document.subscriptionJson, "channel.type", "Subscription")_" --&gt; "_GetFHIRPathOne(Document.subscriptionJson, "channel.endpoint", "Subscription")'></trace>

<send transform="" target="HS.Util.Trace.Operations"></send>
<return></return>
</when>
</rule>
</ruleSet>
</ruleDefinition>
}

}

