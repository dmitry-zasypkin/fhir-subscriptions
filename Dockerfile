ARG IMAGE=intersystemsdc/irishealth-community:latest
FROM $IMAGE

USER root

WORKDIR /opt/irisapp
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisapp

USER ${ISC_PACKAGE_MGRUSER}

COPY src src
COPY data/fhir fhirdata
COPY iris.script /tmp/iris.script

# run iris and initialize
RUN iris start $ISC_PACKAGE_INSTANCENAME \
  && iris session $ISC_PACKAGE_INSTANCENAME < /tmp/iris.script \
  && iris stop $ISC_PACKAGE_INSTANCENAME quietly \
  && rm -f $ISC_PACKAGE_INSTALLDIR/mgr/journal.log \
  && rm -f $ISC_PACKAGE_INSTALLDIR/mgr/IRIS.WIJ \
  && rm -f $ISC_PACKAGE_INSTALLDIR/mgr/iris.ids \
  && rm -f $ISC_PACKAGE_INSTALLDIR/mgr/alerts.log \
  && rm -f $ISC_PACKAGE_INSTALLDIR/mgr/journal/* \
  && rm -f $ISC_PACKAGE_INSTALLDIR/mgr/messages.log \
  && touch $ISC_PACKAGE_INSTALLDIR/mgr/messages.log