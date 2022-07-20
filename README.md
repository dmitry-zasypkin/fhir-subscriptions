# fhir-subscriptions
FHIR [subscriptions](https://www.hl7.org/fhir/r4/subscription.html) processing for FHIR Resource Repository of [InterSystems IRIS for Health](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls) 2022.1+.

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
	Or just download repo contents by clicking the green ```Code``` button and selecting ```Download ZIP```, then unzip the archive to a directory of your choice.

2. In IRIS terminal import [App.Installer](../main/Installer.cls) class into ```USER``` namespace:
	```
	XXX> zn "USER"
	USER> do $System.OBJ.Load("<full path to fhir-subscriptions repo directory>/Installer.cls", "ck")
	```
3. Run [setup()](../main/Installer.cls#L4) method of ```App.Installer``` class passing it the repo directory path, name for the new namespace, web application path for the FHIR endpoint to be created, and other parameters, e.g.:
	```
	zw ##class(App.Installer).setup("C:/Git/fhir-subscriptions", "FHIRSERVER", "/fsub", "isc.ateam.fsub.FSUBInteractionsStrategy", $lb("hl7.fhir.r4.core@4.0.1"), "isc.ateam.fsub.FSUBProduction", "/fsub/mock", "isc.ateam.fsub.mock.DummyRESTHookHandler", $lb("no-payload", "with-payload"), "REST Hook: ")
	```
	It will create the specified namespace backed by a set of databases including a separate database for program code. 
	It will then import the source code into the new namespace, setup FHIR endpoint with the specified path, create two Service Registry entries, configure a mock-up service web application, and appoint [isc.ateam.fsub.FSUBProduction](../main/src/cls/isc/ateam/fsub/FSUBProduction.cls) as the current interoperability production for the namespace.
	Note that FHIR endpoint is based on the specified custom interactions strategy class [isc.ateam.fsub.FSUBInteractionsStrategy](../main/src/cls/isc/ateam/fsub/FSUBInteractionsStrategy.cls).
4. Start the production in the new namespace either using the command ```do ##class(Ens.Director).StartProduction()``` in the same terminal window, or using the Portal.
## Testing with Postman
1. Import [FSUB.postman_collection.json](../main/misc/postman/FSUB.postman_collection.json) file into Postman and adjust ```url``` variable defined for the collection.
2. Post Subscription resource to FHIR Repository using ```POST Subscription``` request from the collection. Criteria element of the resource contains the following [Search](https://www.hl7.org/fhir/r4/search.html) string: ```Patient?identifier=https://hl7.org/fhir/sid/us-ssn|999-99-9990```.
3. Test subscription processing by posting Patient resource and/or Bundle containing Patient resources using the corresponding requests from the collection. Patient resources with SSN=999-99-9990 will trigger interoperability (Ensemble) session that can be examined in the [Portal](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=EMONITOR_message#EMONITOR_message_browsing). E.g.:
  <p align="center"><img src="https://user-images.githubusercontent.com/13035460/178743201-a9dc7959-df15-4c06-910d-d492b42fa30c.png" alt="Visual Trace" width="650"/></p>

## Notification Routing Details
At the moment, only ```rest-hook``` [channel type](https://www.hl7.org/fhir/r4/subscription.html#channels) has been implemented.

REST Hook notifications are broadcast through business operation components of class [isc.ateam.fsub.bo.RESTHookOperation](../main/src/cls/isc/ateam/fsub/bo/RESTHookOperation.cls).

For each endpoint URL that can be a notification target, there should be a pre-configured [HTTP Service Registry](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXREG_ch_service_registry#HXREG_service_registry_settings_http) entry and a corresponding operation component in the interoperability production. So that each operation queues notifications destined for a specific endpoint.

Once [isc.ateam.fsub.FSUBRouterProcess](../main/src/cls/isc/ateam/fsub/FSUBRouterProcess.cls) receives a message containing a Subscription and a set of matching resources, the process extracts target endpoint URL from ```channel.endpoint``` element of the Subscription, and looks in the HTTP Service Registry for an entry whose ```Aliases``` array contains the URL. If a Service Registry entry is found, the process tries to find the business operation component associated with the entry through ```ServiceName``` setting. Finally it routes notification message(s) to the operation.
