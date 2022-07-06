# fhir-subscriptions
FHIR subscriptions processing for FHIR Resource Repository of InterSystems IRIS for Health

## Docker Installation
1. Clone the repo into any local directory, e.g.:
	```
	$ git clone https://github.com/dmitry-zasypkin/fhir-subscriptions.git
	$ cd fhir-subscriptions
	```
2. Get the images: ```docker-compose build --pull```
3. Start docker: ```docker-compose up -d```

## Host Installation
1. Import ```App.Installer``` class into ```USER``` namespace:
	```
	XXX> zn "USER"
	USER> do $System.OBJ.Load("<repo directory>/Installer.cls", "ck")
	```
2. Run [setup() method](../main/Installer.cls#L4) of ```App.Installer``` class passing it repo directory path, name for the new namespace, web application path for the FHIR endpoint to be created, and other parameters, e.g.:
	```
	USER> zw ##class(App.Installer).setup("C:/Git/fhir-subscriptions", "FHIRSERVER", "/fsub", "isc.ateam.fsub.FSUBInteractionsStrategy", $lb("hl7.fhir.r4.core@4.0.1"), "isc.ateam.fsub.FSUBProduction")
	```
It will create the specified namespace and a set of databases including a separate database for program code. 
It will then import the source code into the new namespace, setup FHIR endpoint with the specified path, and start interoperability production [isc.ateam.fsub.FSUBProduction](../main/src/cls/isc/ateam/fsub/FSUBProduction.cls).
## Testing with Postman
1. Import [FSUB.postman_collection.json](../main/misc/postman/FSUB.postman_collection.json) file into Postman and adjust ```url``` variable defined for the collection.
2. Post a Subscription resource to FHIR Repository using ```POST Subscription``` request from the collection.
3. Test subscription processing by posting a Patient resource and/or a Bundle containing Patient resources using corresponding requests from the collection.
