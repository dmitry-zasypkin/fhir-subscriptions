Class isc.ateam.fsub.FSUBProduction Extends Ens.Production
{

/// Dummy business service to act as a FHIR message source
Property InboundFHIRSourceService As Ens.DataType.ConfigName;

/// Business process or operation to receive messages from FHIR infrastructure
Property InboundFHIRTarget As Ens.DataType.ConfigName;

/// FHIR Endpoint (Web Application path).
/// This setting gets its value from Default System Settings entry which is created during installation (hence FHIR endpoint path is not hard coded anywhere in the repo).
Property FHIREndpoint As %String(MAXLEN = 1000);

Parameter SETTINGS = "InboundFHIRSourceService:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=0&productionName=@productionId},InboundFHIRTarget:Basic,FHIREndpoint:Basic";

XData ProductionDefinition
{
<Production Name="isc.ateam.fsub.FSUBProduction" TestingEnabled="true" LogGeneralTraceEvents="true">
  <Description></Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Setting Target="Adapter" Name="InboundFHIRSourceService">FHIR</Setting>
  <Setting Target="Adapter" Name="InboundFHIRTarget">FSUBRouterProcess</Setting>
  <Item Name="FHIR" Category="" ClassName="EnsLib.Testing.Service" PoolSize="0" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="HS.Util.Trace.Operations" Category="" ClassName="HS.Util.Trace.Operations" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="FSUBRouterProcess" Category="" ClassName="EnsLib.MsgRouter.RoutingEngine" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
    <Setting Target="Host" Name="BusinessRuleName">isc.ateam.fsub.FSUBRouterProcessRoutingRule</Setting>
  </Item>
</Production>
}

/// Intialize Subscription cache
ClassMethod OnStart(pTimeStarted As %String) As %Status
{
	#dim sc As %Status = $$$OK
	try
	{
		#dim fhirEndpoint As %String = ##class(Ens.Director).GetCurrProductionSettingValue("FHIREndpoint", .sc)
		if $$$ISERR(sc) quit
	
		#dim strategy As HS.FHIRServer.API.InteractionsStrategy = ##class(HS.FHIRServer.API.InteractionsStrategy).GetStrategyForEndpoint(fhirEndpoint)
		#dim interactions As isc.ateam.fsub.FSUBInteractions = strategy.NewInteractionsInstance()
		#dim globalName As %String = interactions.subscriptionsGlobal
		
		do ##class(isc.ateam.fsub.FSUBInteractions).initializeSubscriptionCache(globalName, interactions, strategy)
	}
	catch ex
	{
		set sc = ex.AsStatus()
	}

	quit sc
}

/// Clean up
ClassMethod OnStop(pTimeStarted As %String, pForced As %Boolean)
{
	#dim sc As %Status = $$$OK
	try
	{
		#dim fhirEndpoint As %String = ##class(Ens.Director).GetCurrProductionSettingValue("FHIREndpoint", .sc)
		if $$$ISERR(sc) quit
		
		#dim strategy As HS.FHIRServer.API.InteractionsStrategy = ##class(HS.FHIRServer.API.InteractionsStrategy).GetStrategyForEndpoint(fhirEndpoint)
		#dim interactions As isc.ateam.fsub.FSUBInteractions = strategy.NewInteractionsInstance()
		
		#dim globalName As %String = interactions.subscriptionsGlobal
		kill @globalName
	}
	catch ex
	{
		set sc = ex.AsStatus()
	}
	
	if $$$ISERR(sc) $$$LOGSTATUS(sc)
}

}

