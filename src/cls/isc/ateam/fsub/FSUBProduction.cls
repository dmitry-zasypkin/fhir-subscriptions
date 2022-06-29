Class isc.ateam.fsub.FSUBProduction Extends Ens.Production
{

/// Dummy business service to act as a FHIR message source
Property InboundFHIRSourceService As Ens.DataType.ConfigName;

/// Business process or operation to receive messages from FHIR infrastructure
Property InboundFHIRTarget As Ens.DataType.ConfigName;

Parameter SETTINGS = "InboundFHIRSourceService:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=0&productionName=@productionId},InboundFHIRTarget:Basic";

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

}

