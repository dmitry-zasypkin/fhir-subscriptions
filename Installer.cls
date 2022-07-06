Class App.Installer [ Abstract ]
{

ClassMethod setup(
	repoRoot As %String,
	namespace As %String,
	appKey As %String,
	strategyClass As %String,
	metadataPackages As %List,
	productionClass As %String) As %Status
{
	// Import class HS.Local.Util.FoundationInstaller
	zn "HSCUSTOM"
	$$$QuitOnError($System.OBJ.Load(repoRoot _ "/src/cls/HS/Local/Util/FoundationInstaller.cls", "ck"))

	// Install a Foundation namespace with a separate db for program code
	zn "HSLIB"
	kill vars
	set vars("CodeDBName") = namespace _ "CODE"  // name for program code database to be created
	$$$QuitOnError(##class(HS.Local.Util.FoundationInstaller).Install(namespace, .vars))
	
	// Change security resource of the program code database we've just created
	zn "%SYS"
	$$$QuitOnError(##class(SYS.Database).ModifyDatabase($system.Util.ManagerDirectory() _ namespace _ "CODE",, "%DB_" _ namespace))
	
	// Change to the new ns
	zn namespace

	// Install elements that are required for a FHIR-enabled namespace
	do ##class(HS.FHIRServer.Installer).InstallNamespace()

	// Import sources
	$$$QuitOnError($System.OBJ.LoadDir(repoRoot _ "/src/cls", "ck", ,1))

	// Install an instance of a FHIR Service into the current namespace
	do ##class(HS.FHIRServer.Installer).InstallInstance(appKey, strategyClass, metadataPackages)

	// Configure FHIR Service instance to accept unauthenticated requests
	#dim strategy As HS.FHIRServer.API.InteractionsStrategy = ##class(HS.FHIRServer.API.InteractionsStrategy).GetStrategyForEndpoint(appKey)
	set config = strategy.GetServiceConfigData()
	set config.DebugMode = 4
	do strategy.SaveServiceConfigData(config)
	
	// Configure production auto-start
	set ^Ens.Configuration("csp", "LastProduction") = productionClass
	$$$QuitOnError(##class(Ens.Director).SetAutoStart(productionClass))

	// Load some FHIR data
	$$$QuitOnError(##class(HS.FHIRServer.Tools.DataLoader).SubmitResourceFiles(repoRoot _ "/fhirdata/", "FHIRServer", appKey))

	/* Uncomment the following code if using Durable %SYS
	
	////////////////// Mark code database read-only in order to keep it inside the container
	zn "%SYS"
	set dbDir = $piece(##class(Config.Databases).DatabaseByName(namespace _ "CODE"), "^", *)
	write "Code database dir: " _ dbDir,!

	set db = ##class(SYS.Database).%OpenId(dbDir,, .sc)
	$$$QuitOnError(sc)
	set db.ReadOnly = 1
	set db.ResourceName = "%DB_"_$ZCVT(namespace,"U")
	$$$QuitOnError(db.%Save())
	*/

	quit $$$OK
}

}