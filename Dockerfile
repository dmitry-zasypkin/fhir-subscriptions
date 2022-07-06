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
  set sc = ##class(App.Installer).setup()

# bringing the standard shell back
SHELL ["/bin/bash", "-c"]

