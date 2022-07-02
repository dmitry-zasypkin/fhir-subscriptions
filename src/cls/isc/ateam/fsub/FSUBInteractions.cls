Include Ensemble

Class isc.ateam.fsub.FSUBInteractions Extends HS.FHIRServer.Storage.Json.Interactions
{

/// For ReadAndLock() method (not in use currently)
Parameter lockTIMEOUT = 10;

/// Production setting that specifies name of the business service which is the source of FHIR requests
Parameter fhirRequestsSourceNameSETTING = "InboundFHIRSourceService";

/// Production setting that specifies name of the business process/operation which is the target for FHIR requests
Parameter fhirRequestsTargetNameSETTING = "InboundFHIRTarget";

Property currentFHIRService As HS.FHIRServer.API.Service [ Private, Transient ];

Property currentFHIRRequestStream As %Stream.TmpCharacter [ Private, Transient ];

Property currentSessionId As %Integer [ Private, Transient ];

Property currentListOfErrors As list Of isc.ateam.fsub.msg.OneErrorSerial [ Private, Transient ];

Property subscriptionsGlobal As %String [ InitialExpression = {$name($$$EnsRuntimeAppData($classname(), "subscriptionCache"))} ];

Method OnBeforeRequest(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pTimeout As %Integer)
{
	// initialize the properties
	set ..currentFHIRService = pFHIRService
	set ..currentSessionId = ""
	do ..currentListOfErrors.Clear()
	
	// retrieve and cache criteria values of all active, non-deleted Subscription resources into @..subscriptionsGlobal
	// TODO: initialize the cache on Production start(?); then for every request check new Subscriptions only using "lastUpdated" element
	do ..initializeSubscriptionCache()
	
	// memorize original JSON for logging purposes
	set ..currentFHIRRequestStream = ""
	if $isObject(pFHIRRequest.Json) do pFHIRRequest.Json.%ToJSON(..currentFHIRRequestStream)
	
	do ##super(pFHIRService, pFHIRRequest, pTimeout)
}

Method OnAfterRequest(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pFHIRResponse As HS.FHIRServer.API.Data.Response)
{
	do ##super(pFHIRService, pFHIRRequest, pFHIRResponse)
	
	// notify production of errors (if any) encountered during subscriptions processing
	if (..currentListOfErrors.Count() > 0)
	{
		try
		{
			#dim message As isc.ateam.fsub.msg.FHIRErrorNotification = ##class(isc.ateam.fsub.msg.FHIRErrorNotification).%New(
					pFHIRRequest, 
					pFHIRResponse, 
					..currentFHIRRequestStream)
			
			set message.errors = ..currentListOfErrors

			// send message asynchronously
			do ..sendToProductionAsync(message, "Subscription processing errors")
		}
		catch ex
		{
			// "swallow" the exception and log it somewhere
			// TODO: any better place to log such exceptions (which are pretty unlikely to happen btw)?
			$$$FSLog("*** ERROR *** Exception when constructing/sending message to production: "_ $$$StatusDisplayString(ex.AsStatus()))
		}
	}
	
	// clean up
	set ..currentFHIRRequestStream = ""
	do ..currentListOfErrors.Clear()
}

/// Intercept Add() to apply subsriptions to new resources.
/// pHttpMethod is "PUT" here in case of update/create with a non-existent "id" specified in the request.
/// TODO: redesign and move this logic to OnAfterRequest() as the changes may be rolled back by transaction Bundle processing methods
Method Add(pResourceObj As %DynamicObject, pResourceIdToAssign As %String = "", pHttpMethod = "POST") As %String
{
	#dim rsrcId As %String = ##super(pResourceObj, pResourceIdToAssign, pHttpMethod)
	
	try
	{
		do ..applySubscriptionsToResource(pResourceObj.resourceType, rsrcId, pHttpMethod)
	}
	catch ex
	{
		do ..logError(pResourceObj, pHttpMethod, rsrcId, ex)
	}
	
	quit rsrcId
}

/// Intercept Update() to apply subsriptions to updated resources
/// TODO: redesign and move this logic to OnAfterRequest() as the changes may be rolled back by transaction Bundle processing methods
Method Update(pResourceObj As %DynamicObject) As %String
{
	#dim rsrcId As %String = ##super(pResourceObj)

	try
	{
		do ..applySubscriptionsToResource(pResourceObj.resourceType, rsrcId, "PUT")
	}
	catch ex
	{
		do ..logError(pResourceObj, "PUT", rsrcId, ex)
	}

	quit rsrcId
}

Method applySubscriptionsToResource(resourceType As %String, resourceId As %String, httpMethod As %String)
{
	#dim idSearchParam As HS.FHIRServer.SearchParam = ..currentFHIRService.strategy.schema.FindSearchParam("Subscription", "_id")
	#dim idQueryParam As HS.FHIRServer.API.SearchQueryParameter = ##class(HS.FHIRServer.API.SearchQueryParameter).%New("_id", resourceId,, idSearchParam)
	
	// list to hold IDs of matching Subscriptions
	#dim subsIdList As %List = ""
	
	// loop over all Subscriptions in the cache (@..subscriptionsGlobal)
	#dim subsId As %Integer = ""
	for
	{
		#dim queryString As %String = ""
		set subsId = $order(@..subscriptionsGlobal@(subsId), 1, queryString)
		if (subsId = "") quit
		
		// skip Subscriptions relevant to some other resourceType
		if (@..subscriptionsGlobal@(subsId, "type") '= resourceType) continue
		
		// skip Subscriptions with criteria containing "_id" parameter with a non-matching value
		#dim idInCriteria As %String = $get(@..subscriptionsGlobal@(subsId, "_id"))
		if (idInCriteria '= "") && (idInCriteria '= resourceId) continue
		
		// parse queryString
		#dim params As HS.FHIRServer.API.Data.QueryParameters = ##class(HS.FHIRServer.API.Data.QueryParameters).CreateFromQueryString(
				queryString, 
				..currentFHIRService.strategy.schema, 
				resourceType)
		
		// append _id=<resourceId> to queryString and try to use the result to find the resource
		do params.AddParameter(idQueryParam)
		
		#dim resultSet As HS.FHIRServer.Util.SearchResult = ..Search(resourceType, "", "", params)
		while resultSet.%Next() 
		{
			// skip deleted resources
			if resultSet.IsDeleted continue
			
			// if resource id matches, then memorize Subscription id to subsIdList
			if (resultSet.ResourceId = resourceId)
			{
				set subsIdList = subsIdList _ $lb(subsId)
				$$$FSLog("Found matching Subscription (id=" _ subsId _ "): " _ resourceType _ "?" _ queryString)
				quit
			}
		} // while
	} // for
	
	// check if we found at least one matching Subscription
	if (subsIdList = "") quit
	
	// construct notification message and send it to Production
	#dim message As isc.ateam.fsub.msg.FSUBNotification = ##class(isc.ateam.fsub.msg.FSUBNotification).%New()
	set message.resourceId = resourceId
	set message.resourceType = resourceType
	set message.httpMethod = httpMethod
	
	// serialize the resource to message.resourceStream
	#dim rsrc As %DynamicObject = ..Read(resourceType, resourceId)
	do rsrc.%ToJSON(message.resourceStream)
	kill rsrc
	
	// loop over Subscriptions and pack them into the message
	for i = 1:1:$listLength(subsIdList)
	{
		set subsId = $listGet(subsIdList, i)
		
		#dim subs As %DynamicObject = ..Read("Subscription", subsId)
		if '$isObject(subs) continue
		
		// skip expired Subscriptions
		if (subs.end '= "")
		{
			#dim endTS As %TimeStamp = ##class(%TimeStamp).XSDToLogical(subs.end)  // UTC
			if (endTS '= "") && (0 <= $System.SQL.DATEDIFF("ms", endTS, $zdatetime($ztimestamp, 3, 1, 3)))
			{
				$$$FSLog("Skipping expired Subscription; end=" _ subs.end _ ", id=" _ subsId)
				continue
			}
		}
		
		// serialize Subscription resource to message.subscription list entry
		do message.subscription.Insert("")
		do subs.%ToJSON(message.subscription.GetAt(message.subscription.Count()))
	} // for
	
	// check if we have any non-expired Subscriptions, and send the notification message
	if (message.subscription.Count() > 0)
	{
		#dim description As %String = httpMethod _ " " _ resourceType _ "/" _ resourceId
		do ..sendToProductionAsync(message, description)
	}
}

Method logError(rsrc As %DynamicObject, httpMethod As %String, rsrcId As %String, exception As %Exception.AbstractException) As isc.ateam.fsub.msg.OneErrorSerial [ Private ]
{
	#dim newItem As isc.ateam.fsub.msg.OneErrorSerial = ""
	
	try
	{
		do ..currentListOfErrors.Insert("")
		set newItem = ..currentListOfErrors.GetAt(..currentListOfErrors.Count())
		
		set newItem.resourceType = rsrc.resourceType
		set newItem.resourceId = rsrcId
		do rsrc.%ToJSON(newItem.resourceStream)
		set newItem.httpMethod = httpMethod
		set newItem.status = exception.AsStatus()
		set newItem.errorCodes = $System.Status.GetErrorCodes(newItem.status)
		set newItem.errorText = $System.Status.GetErrorText(newItem.status)

		#dim stack
		do exception.StackAsArray(.stack)
		if $data(stack) && (+$get(stack) > 1)
		{
			#dim stackList As %List = ""
			for i = +$get(stack):-1:2 set stackList = stackList _ $lb($get(stack(i, "PLACE")))

			do newItem.stack.InsertList(stackList)
		}
	}
	catch ex
	{
		// "swallow" the exception and log it somewhere
		// TODO: any better place to log such exceptions (which are pretty unlikely to happen btw)?
		$$$FSLog("*** ERROR *** Exception when constructing isc.ateam.fsub.msg.OneErrorSerial object: "_ $$$StatusDisplayString(ex.AsStatus()))
	}
	
	quit newItem
}

Method sendToProductionAsync(request As %Persistent, messageDescription As %String = "")
{
	do ..sendToProduction($$$NO, request,,, messageDescription)
}

Method sendToProductionSync(request As %Persistent, Output response As %Persistent, syncTimeOut As %Numeric = -1, messageDescription As %String = "")
{
	do ..sendToProduction($$$YES, request, .response, syncTimeOut, messageDescription)
}

Method sendToProduction(isSync As %Boolean, request As %Persistent, Output response As %Persistent, syncTimeOut As %Numeric = -1, messageDescription As %String = "") [ Private ]
{
	#dim sc As %Status = $$$OK
	
	#dim source As %String = ##class(Ens.Director).GetCurrProductionSettingValue(..#fhirRequestsSourceNameSETTING, .sc)
	$$$ThrowOnError(sc)
	
	#dim target As %String = ##class(Ens.Director).GetCurrProductionSettingValue(..#fhirRequestsTargetNameSETTING, .sc)
	$$$ThrowOnError(sc)
	
	#dim service As Ens.BusinessService
	$$$ThrowOnError(##class(Ens.Director).CreateBusinessService(source, .service))
	
	if isSync
	{
		set sc = service.SendRequestSync(target, request, .response, syncTimeOut, messageDescription)
	}
	else
	{
		set sc = service.SendRequestAsync(target, request, messageDescription)
	}
	
	set ..currentSessionId = service.%SessionId
	$$$ThrowOnError(sc)
}

/// TODO: filter out expired Subscriptions here (check "end" element against the current date)
/// TODO: initialize the cache on Production start(?); then for every request check new Subscriptions only using "lastUpdated" element
Method initializeSubscriptionCache() [ Private ]
{
	kill @..subscriptionsGlobal
	
	#dim susbcrSearchTable As %String = ..currentFHIRService.strategy.GetSearchTable("Subscription")
	#dim rsrcClass As %String = ..currentFHIRService.strategy.GetResourceClass("Subscription")
	
	//kill sqlParams
	//set sqlParams($i(sqlParams)) = "off"

	#dim sql As %String = ""
	set sql = "SELECT t0._id, t0._lastUpdated, t0.criteria FROM " _ susbcrSearchTable _ " t0 " _ 
						" WHERE %NOINDEX t0.status != 'off' AND t0.criteria IS NOT NULL " _
						" ORDER BY 1 ASC "

	#dim sqlResultSet As %SQL.StatementResult = ..runQuery(sql)  // ..runQuery(sql, .sqlParams)
	while (sqlResultSet.%Next())
	{
		#dim id As %Integer = +sqlResultSet.%GetData(1)
		//#dim lastUpdated As %String = sqlResultSet.%GetData(2)
		#dim criteria As %String = sqlResultSet.%GetData(3)
		
		// skip deleted Subscriptions
		if $classmethod(rsrcClass, "KeyIdxExists", "Subscription/" _ id, .tempId)
				&& ($classmethod(rsrcClass, "DeletedGetStored", tempId) = $$$YES)
		{
			continue
		}

		set @..subscriptionsGlobal@(id) = $piece(criteria, "?", 2, *)
		set @..subscriptionsGlobal@(id, "type") = $piece(criteria, "?", 1)
		
		// parse criteria
		#dim params As HS.FHIRServer.API.Data.QueryParameters = ##class(HS.FHIRServer.API.Data.QueryParameters).CreateFromQueryString(
				@..subscriptionsGlobal@(id), 
				..currentFHIRService.strategy.schema, 
				@..subscriptionsGlobal@(id, "type"))
			
		// search for _id just in case
		for i = 1:1:params.Count()
		{
			#dim item As HS.FHIRServer.API.SearchQueryParameter = params.GetAt(i)
			if (item.name = "_id")
			{
				set @..subscriptionsGlobal@(id, "_id") = item.value
				quit
			}
		} // for
		
	} // while
}

/// Not used
Method ReadAndLock(pResourceType As %String, pResourceId As %String, pVersionId As %String = "") As %DynamicObject
{
	#dim lock As %String = "FHIR" _ pResourceType _ pResourceId _ "v" _ pVersionId
	
	lock +@lock:..#lockTIMEOUT
	if '$TEST $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot lock the resource: " _ pResourceType _ "/" _ pResourceId))
	
	try
	{
		#dim result As %DynamicObject = ..Read(pResourceType, pResourceId, pVersionId)
	}
	catch ex
	{
		lock -@lock
		throw ex
	}
	
	quit result
}

/// Not used
Method Unlock(pResourceType As %String, pResourceId As %String, pVersionId As %String = "")
{
	#dim lock As %String = "FHIR" _ pResourceType _ pResourceId _ "v" _ pVersionId
	lock -@lock
}

}

