Class App.Installer [ Abstract ]
{

ClassMethod setup(
	repoRoot As %String,
	namespace As %String,
	appKey As %String,
	strategyClass As %String,
	metadataPackages As %List,
	productionClass As %String,
	mockAppPath As %String,
	mockRestHandlerClass As %String,
	mockEndpointSuffixes As %List,
	mockOperationPrefix As %String) As %Status
{
	new $namespace

	// Install a Foundation namespace
	zn "HSLIB"
	$$$QuitOnError(##class(HS.Util.Installer.Foundation).Install(namespace))
	
	zn "%SYS"
	// Create web app to receive requests directed to mock-up services
	kill prop
	set prop("AutheEnabled") = $$$AutheUnauthenticated
	set prop("NameSpace") = namespace
	set prop("DispatchClass") = mockRestHandlerClass
	set prop("MatchRoles") = ":%HS_DB_"_$tr(namespace, "%")
	$$$QuitOnError(##class(Security.Applications).Create(mockAppPath, .prop))
	
	// Change to the new ns
	zn namespace

	// Set production class
	set ns = ##class(HS.Util.Installer.Foundation).%OpenId(namespace)
	set ns.Production = productionClass
	$$$QuitOnError(ns.%Save())

	// Install elements that are required for a FHIR-enabled namespace
	do ##class(HS.FHIRServer.Installer).InstallNamespace()

	// Import sources
	$$$QuitOnError($System.OBJ.LoadDir(repoRoot _ "/src/cls", "ck", ,1))
	
	// Configure production auto-start
	set ^Ens.Configuration("csp", "LastProduction") = productionClass
	$$$QuitOnError(##class(Ens.Director).SetAutoStart(productionClass))
	
	// Create "System Default Settings" entry for FHIREndpoint production-level setting 
	set ds = ##class(Ens.Config.DefaultSettings).%New()
	set ds.ProductionName = productionClass
	set ds.ItemName = "*"
	set ds.HostClassName = "*"
	set ds.SettingName = "FHIREndpoint"
	set ds.SettingValue = appKey
	set ds.Deployable = $$$YES
	
	// just in case: delete existing entry
	&SQL(DELETE FROM Ens_Config.DefaultSettings 
		WHERE ProductionName = :ds.ProductionName 
			AND ItemName = :ds.ItemName
			AND HostClassName = :ds.HostClassName
			AND SettingName = :ds.SettingName)
	
	$$$QuitOnError(ds.%Save())

	// Install an instance of a FHIR Service into the current namespace
	do ##class(HS.FHIRServer.Installer).InstallInstance(appKey, strategyClass, metadataPackages)

	// Configure FHIR Service instance to accept unauthenticated requests
	#dim strategy As HS.FHIRServer.API.InteractionsStrategy = ##class(HS.FHIRServer.API.InteractionsStrategy).GetStrategyForEndpoint(appKey)
	set config = strategy.GetServiceConfigData()
	set config.DebugMode = 4
	do strategy.SaveServiceConfigData(config)
	
	// Load some FHIR data from either "fhirdata" or "data/fhir" directories
	#dim dataDir As %String = repoRoot _ "/fhirdata/"
	if '##class(%File).DirectoryExists(dataDir) set dataDir = repoRoot _ "/data/fhir/"
	$$$QuitOnError(##class(HS.FHIRServer.Tools.DataLoader).SubmitResourceFiles(dataDir, "FHIRServer", appKey))
	
	// Create "Service Registry" and "System Default Settings" entries for mock-up HTTP services
	set sc = $$$OK
	for i = 1:1:$listLength(mockEndpointSuffixes)
	{
		set name = $listGet(mockEndpointSuffixes, i)
		
		// 1. create Service Registry entry for mock-up service
		#dim newEntry As HS.Registry.Service.HTTP = ##class(HS.Registry.Service.HTTP).%New()
		set newEntry.Type = "HTTP"
		set newEntry.Name = name
		set newEntry.URL = mockAppPath _ "/" _ name
		set newEntry.Host = "localhost"
		set newEntry.Port = ^%SYS("WebServer","Port")
		
		set fullUrl = "http://" _ newEntry.Host _ ":" _ newEntry.Port _ newEntry.URL
		do newEntry.ServiceAliases.Insert(fullUrl)
		
		// just in case: delete existing entry
		&SQL(DELETE FROM HS_Registry_Service.HTTP WHERE Name = :newEntry.Name AND Type = :newEntry.Type)
		
		set sc = newEntry.%Save()
		if $$$ISERR(sc) quit
		
		// 2. create "System Default Settings" entry for "ServiceName" setting that belongs to business operations which call mock-up services
		set ds = ##class(Ens.Config.DefaultSettings).%New()
		set ds.ProductionName = productionClass
		set ds.ItemName = mockOperationPrefix _ name
		set ds.HostClassName = "*"
		set ds.SettingName = "ServiceName"
		set ds.SettingValue = name
		set ds.Deployable = $$$YES
		
		// just in case: delete existing entry
		&SQL(DELETE FROM Ens_Config.DefaultSettings 
			WHERE ProductionName = :ds.ProductionName 
				AND ItemName = :ds.ItemName
				AND HostClassName = :ds.HostClassName
				AND SettingName = :ds.SettingName)
		
		set sc = ds.%Save()
		if $$$ISERR(sc) quit
	} // for
	
	$$$QuitOnError(sc)

	quit $$$OK
}

}
