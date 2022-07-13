ARG IMAGE=intersystemsdc/irishealth-community:latest
FROM $IMAGE

USER root

WORKDIR /opt/irisapp
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisapp

COPY irissession.sh /
RUN chmod +x /irissession.sh

USER ${ISC_PACKAGE_MGRUSER}

COPY src src
COPY data/fhir fhirdata
COPY Installer.cls Installer.cls

# run iris and initialize
SHELL ["/irissession.sh"]

RUN \
  do $System.OBJ.Load("Installer.cls", "ck") \
  set repoRoot = $system.Process.CurrentDirectory() \
  set namespace = "FHIRSERVER" \
  set appKey = "/fsub" \
  set strategyClass = "isc.ateam.fsub.FSUBInteractionsStrategy" \
  set metadataPackages = $lb("hl7.fhir.r4.core@4.0.1") \
  set productionClass = "isc.ateam.fsub.FSUBProduction" \
  set mockAppPath = "/fsub/mock" \
  set mockEndpointSuffixes = $lb("no-payload", "with-payload") \
  set mockRestHandlerClass = "isc.ateam.fsub.mock.DummyRESTHookHandler" \
  set mockOperationPrefix = "REST Hook: " \
  set sc = ##class(App.Installer).setup(repoRoot, namespace, appKey, strategyClass, metadataPackages, productionClass, mockAppPath, mockRestHandlerClass, mockEndpointSuffixes, mockOperationPrefix)

# bringing the standard shell back
SHELL ["/bin/bash", "-c"]

