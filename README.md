# fhir-subscriptions
FHIR subscriptions processing for FHIR Resource Repository of InterSystems IRIS for Health 2022.1+.

## Docker Installation
1. Clone the repo into any local directory, e.g.:
	```
	$ git clone https://github.com/dmitry-zasypkin/fhir-subscriptions.git
	$ cd fhir-subscriptions
	```
2. Get the images: ```docker-compose build --pull```
3. Start docker: ```docker-compose up -d```

## Host Installation
1. Clone the repo into any local directory, e.g.:
	```
	C:\Git> git clone https://github.com/dmitry-zasypkin/fhir-subscriptions.git
	```
2. In IRIS terminal import [App.Installer](../main/Installer.cls) class into ```USER``` namespace:
	```
	XXX> zn "USER"
	USER> do $System.OBJ.Load("<full path to fhir-subscriptions repo directory>/Installer.cls", "ck")
	```
3. Run [setup()](../main/Installer.cls#L4) method of ```App.Installer``` class passing it the repo directory path, name for the new namespace, web application path for the FHIR endpoint to be created, and other parameters, e.g.:
	```
	zw ##class(App.Installer).setup("C:/Git/fhir-subscriptions", "FHIRSERVER", "/fsub", "isc.ateam.fsub.FSUBInteractionsStrategy", $lb("hl7.fhir.r4.core@4.0.1"), "isc.ateam.fsub.FSUBProduction")
	```
	It will create the specified namespace backed by a set of databases including a separate database for program code. 
	It will then import the source code into the new namespace, setup FHIR endpoint with the specified path, and appoint [isc.ateam.fsub.FSUBProduction](../main/src/cls/isc/ateam/fsub/FSUBProduction.cls) as the current interoperability production for the namespace.
	Note that FHIR endpoint is based on the specified custom interactions strategy class [isc.ateam.fsub.FSUBInteractionsStrategy](../main/src/cls/isc/ateam/fsub/FSUBInteractionsStrategy.cls).
4. Start the production in the new namespace either using the command ```do ##class(Ens.Director).StartProduction()``` in the same terminal window, or using the Portal.
## Testing with Postman
1. Import [FSUB.postman_collection.json](../main/misc/postman/FSUB.postman_collection.json) file into Postman and adjust ```url``` variable defined for the collection.
2. Post Subscription resource to FHIR Repository using ```POST Subscription``` request from the collection. Criteria element of the resource contains the following [Search](https://www.hl7.org/fhir/r4/search.html) string: ```Patient?identifier=https://hl7.org/fhir/sid/us-ssn|999-99-9990```.
3. Test subscription processing by posting Patient resource and/or Bundle containing Patient resources using the corresponding requests from the collection. Patient resources with SSN=999-99-9990 will trigger interoperability (Ensemble) session that can be examined in the Portal.
