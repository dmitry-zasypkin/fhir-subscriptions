/// 
Class isc.ateam.fsub.FSUBRouterProcessRoutingRule Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "EnsLib.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="EnsLib.MsgRouter.RoutingEngine" production="isc.ateam.fsub.FSUBProduction">
<ruleSet name="" effectiveBegin="" effectiveEnd="">
<assign property="Document.resourceJson" value="FromJSON(Document.resourceStream)"></assign>
<assign property="Document.subscriptionJsonArray" value="ArrayFromJSON(Document.subscription)"></assign>
<trace value="Document.httpMethod_&quot; &quot;_Document.resourceType_&quot;/&quot;_ Document.resourceId"></trace>
<trace value='"SSN of the Patient: "_GetFHIRPathOne(Document.resourceJson, "identifier.where(system=&apos;https://hl7.org/fhir/sid/us-ssn&apos;).value", Document.resourceType)'></trace>
<trace value='"Criteria of the first Subscription: "_GetFHIRPathOne(GetEntry(Document.subscriptionJsonArray, 0), "criteria", "Subscription")'></trace>
<rule name="rule1">
<when condition="1=1">
<send transform="" target="HS.Util.Trace.Operations"></send>
<return></return>
</when>
</rule>
</ruleSet>
</ruleDefinition>
}

}

