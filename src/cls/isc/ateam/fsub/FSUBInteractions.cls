Include Ensemble

Class isc.ateam.fsub.FSUBInteractions Extends HS.FHIRServer.Storage.Json.Interactions
{

/* NB: After modifying this class, make sure to reset the endpoint using this command:
	do ##class(HS.FHIRServer.Service).InvalidateInstances((##class(HS.FHIRServer.API.InteractionsStrategy).GetStrategyForEndpoint("/fsub")).InstanceKey)  kill ^FSLOG
*/
/// @API
/// Declares the name of the class that will be used to validate FHIR resources.
Parameter ResourceValidatorClass = "isc.ateam.fsub.SubscriptionValidator";

Parameter lockTIMEOUT = 10;

/// Production setting that specifies name of the business service which is the source of FHIR requests
Parameter fhirRequestsSourceNameSETTING = "InboundFHIRSourceService";

/// Production setting that specifies name of the business process/operation which is the target for FHIR requests
Parameter fhirRequestsTargetNameSETTING = "InboundFHIRTarget";

Property currentFHIRService As HS.FHIRServer.API.Service [ Private, Transient ];

Property currentFHIRRequestStream As %Stream.TmpCharacter [ Private, Transient ];

Property currentSessionId As %Integer [ Private, Transient ];

Property currentListOfErrors As list Of isc.ateam.fsub.msg.OneErrorSerial [ Private, Transient ];

Property subscriptionsGlobal As %String [ InitialExpression = {$name($$$EnsRuntimeAppData($classname(), "s"))} ];

Property currentResourcesToBeProcessed [ MultiDimensional, Private, Transient ];

Property underscoreIdSearchParam As HS.FHIRServer.SearchParam [ Private, Transient ];

Method OnBeforeRequest(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pTimeout As %Integer)
{
	// initialize the properties
	set ..currentFHIRService = pFHIRService
	set ..currentSessionId = ""
	set ..currentListOfErrors = ""
	kill ..currentResourcesToBeProcessed
	
	if '$isObject(..underscoreIdSearchParam)
	{
		set ..underscoreIdSearchParam = pFHIRService.strategy.schema.FindSearchParam("Resource", "_id")
	}
	
	// if Subscription cache has not been initialized on Production start, then initialize it here
	if '$data(@..subscriptionsGlobal)
	{
		do ..initializeSubscriptionCache(..subscriptionsGlobal, $this, pFHIRService.strategy)
	}
	
	// memorize original JSON for logging purposes
	set ..currentFHIRRequestStream = ""
	if $isObject(pFHIRRequest.Json) do pFHIRRequest.Json.%ToJSON(..currentFHIRRequestStream)
	
	do ##super(pFHIRService, pFHIRRequest, pTimeout)
}

Method OnAfterRequest(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pFHIRResponse As HS.FHIRServer.API.Data.Response)
{
	do ##super(pFHIRService, pFHIRRequest, pFHIRResponse)
	
	// skip subscription processing in case of error HTTP status
	if (+pFHIRResponse.Status < 300)
	{
		do ..onAfterRequestInternal(pFHIRService, pFHIRRequest, pFHIRResponse)
	}
	
	// clean up
	set ..currentFHIRRequestStream = ""
	set ..currentListOfErrors = ""
	kill ..currentResourcesToBeProcessed
}

Method onAfterRequestInternal(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pFHIRResponse As HS.FHIRServer.API.Data.Response) [ Private ]
{
	///////////// loop over types of the resources that have been added/updated during the request processing
	//							--> apply subscriptions to resources, and send notifications to production
	try
	{
		#dim resourceType As %String = ""
		for
		{
			set resourceType = $order(..currentResourcesToBeProcessed(resourceType))
			if (resourceType = "") quit
			
			// local array to hold IDs of resources and matching Subscriptions
			kill matchesArray
			
			// populate matchesArray
			do ..applySubscriptionsToCurrentResources(resourceType, .matchesArray)
			
			// check if we found at least one resource matching one Subscription
			if $data(matchesArray)
			{
				do ..sendNotifications(resourceType, .matchesArray)
			}
		}
		
		kill matchesArray
	}
	catch ex
	{
		// "swallow" fatal exceptions and log them somewhere
		// TODO: any better place to log such exceptions (which are pretty unlikely to happen btw)?
		$$$FSLog("*** ERROR *** Fatal exception when processing subscriptions: "_ $$$StatusDisplayString(ex.AsStatus()))
	}
	
	
	/////////// notify production of errors (if any) encountered during subscription processing
	//
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
			// "swallow" fatal exceptions and log them somewhere
			// TODO: any better place to log such exceptions (which are pretty unlikely to happen btw)?
			$$$FSLog("*** ERROR *** Exception when constructing/sending message to production: "_ $$$StatusDisplayString(ex.AsStatus()))
		}
	} // if (..currentListOfErrors.Count() > 0)
}

/// Intercept Add() to apply subsriptions to new resources in OnAfterRequest() method.
/// pHttpMethod is "PUT" here in case of update/create with a non-existent "id" specified in the request.
/// TODO: on Subscription creation.. 
///   - change "status" as per FHIR spec: 'Once the server has activated the subscription, it sets the status to "active" (note: the server can do this as it accepts the resource if it wants).'
///   - add new Subscription to cache (@..subscriptionsGlobal)
Method Add(pResourceObj As %DynamicObject, pResourceIdToAssign As %String = "", pHttpMethod = "POST") As %String
{
	#dim rsrcId As %String = ##super(pResourceObj, pResourceIdToAssign, pHttpMethod)
	
	set ..currentResourcesToBeProcessed(pResourceObj.resourceType, rsrcId) = pHttpMethod
		
	quit rsrcId
}

/// Intercept Update() to apply subsriptions to updated resources in OnAfterRequest() method
/// TODO: on Subscription change - update Subscription cache entry in @..subscriptionsGlobal
Method Update(pResourceObj As %DynamicObject) As %String
{
	#dim rsrcId As %String = ##super(pResourceObj)

	set ..currentResourcesToBeProcessed(pResourceObj.resourceType, rsrcId) = "PUT"

	quit rsrcId
}

/// Returns VersionId for the "deleted" version
Method Delete(pResourceType As %String, pResourceId As %String) As %String
{
	#dim version As %String = ##super(pResourceType, pResourceId)
	
	// TODO: on Subscription deletion - remove Subscription cache entry from @..subscriptionsGlobal
	
	quit version
}

/// Apply subscriptions (cached in @..subscriptionsGlobal) to created/updated resources from ..currentResourcesToBeProcessed
/// matchesArray holds IDs of resources and matching Subscriptions.
Method applySubscriptionsToCurrentResources(resourceType As %String, ByRef matchesArray) [ Private ]
{
	// check if we have any Subscription for this resourceType
	if '$data(@..subscriptionsGlobal@(resourceType)) quit
	
	// array to hold ID pairs: <resource Id> + <matching Subscription Id>
	kill matchesArray
	
	// loop over all Subscriptions in the cache (@..subscriptionsGlobal)
	#dim subsId As %Integer = ""
	for
	{
		#dim queryString As %String = ""
		set subsId = $order(@..subscriptionsGlobal@(resourceType, subsId), 1, queryString)
		if (subsId = "") quit
		
		// skip expired Subscriptions
		#dim endTS As %TimeStamp = $get(@..subscriptionsGlobal@(resourceType, subsId, "end"))
		if (endTS '= "") && (0 <= $System.SQL.DATEDIFF("ms", endTS, $zdatetime($ztimestamp, 3, 1, 3)))
		{
			continue
		}
		
		#dim idInCriteria As %String = $get(@..subscriptionsGlobal@(resourceType, subsId, "_id"))
		
		// parse queryString
		#dim params As HS.FHIRServer.API.Data.QueryParameters = ""
		if (queryString '= "")
		{
			set params = ##class(HS.FHIRServer.API.Data.QueryParameters).CreateFromQueryString(
				queryString, 
				..currentFHIRService.strategy.schema, 
				resourceType)
		}
		
		// loop over created/updated resources from ..currentResourcesToBeProcessed
		#dim resourceId As %String = ""
		for
		{
			#dim httpMethod As %String = ""
			set resourceId = $order(..currentResourcesToBeProcessed(resourceType, resourceId), 1, httpMethod)
			if (resourceId = "") quit

			if (queryString = "")
			{
				// no query string --> the Subscription applies to any resource of this type
				// memorize id's of both Subscription and the current resource to matchesArray
				do ..logEntryToMatchesArray(.matchesArray, resourceType, subsId, resourceId, "")
				continue
			}

			// skip resource if the Subscription has "_id" in its criteria, and it doesn't match the id of the current resource
			if (idInCriteria '= "") && (idInCriteria '= resourceId) continue

			// append _id=<resourceId> to queryString and use the result in Search request trying to find the same resource
			#dim idQueryParam As HS.FHIRServer.API.SearchQueryParameter = ##class(HS.FHIRServer.API.SearchQueryParameter).%New("_id", resourceId,, ..underscoreIdSearchParam)
			do params.AddParameter(idQueryParam)
				
			try
			{
				#dim resultSet As HS.FHIRServer.Util.SearchResult = ..Search(resourceType, "", "", params)
				while resultSet.%Next() 
				{
					// skip deleted resources
					if resultSet.IsDeleted continue
					
					// skip the resource if id does not match (should never happen)
					if (resultSet.ResourceId '= resourceId) continue
					
					// memorize id's of both Subscription and the resource to matchesArray
					do ..logEntryToMatchesArray(.matchesArray, resourceType, subsId, resourceId, queryString)

					quit

				} // while
			}
			catch ex
			{
				// log exception to ..currentListOfErrors and proceed to next resource
				do ..logError(resourceType,, httpMethod, resourceId, ex)
			}
			
			// remove _id=<resourceId> condition from queryString
			do params.RemoveParameter(idQueryParam)
			
		} // for loop over created/updated resources
	} // for loop over all Subscriptions
}

Method logEntryToMatchesArray(ByRef matchesArray, resourceType As %String, subsId As %String, resourceId As %String, queryString As %String) [ Private ]
{
	$$$FSLog("Found Subscription (id=" _ subsId _ ") matching resource " _ resourceType _ "/" _ resourceId _ ": " _ resourceType _ "?" _ queryString)

	#dim rsrcIdList As %List = $get(matchesArray(resourceType, subsId))
	set rsrcIdList = rsrcIdList _ $lb(resourceId)
	set matchesArray(resourceType, subsId) = rsrcIdList

	// read json of the Subscription and cache it to matchesArray
	if '$data(matchesArray(resourceType, subsId, "json"))
	{
		set matchesArray(resourceType, subsId, "json") = ..Read("Subscription", subsId)
	}
	
	// read json of the resource and cache it to ..currentResourcesToBeProcessed
	if '$data(..currentResourcesToBeProcessed(resourceType, resourceId, "json"))
	{
		set ..currentResourcesToBeProcessed(resourceType, resourceId, "json") = ..Read(resourceType, resourceId)
	}
}

Method sendNotifications(resourceType As %String, ByRef matchesArray) [ Private ]
{
	// loop over Subscriptions in matchesArray and send notifications
	#dim subsId As %Integer = ""
	for
	{
		#dim rsrcIdList As %List = ""
		set subsId = $order(matchesArray(resourceType, subsId), 1, rsrcIdList)
		if (subsId = "") quit
		
		#dim subsJson As %DynamicObject = $get(matchesArray(resourceType, subsId, "json"))
		
		// skip incomplete subscriptions
		if '$isObject(subsJson) || (rsrcIdList = "") continue
		
		// construct notification message
		#dim message As isc.ateam.fsub.msg.FSUBNotification = ##class(isc.ateam.fsub.msg.FSUBNotification).%New()
		set message.subscriptionId = subsId
		set message.subscriptionCriteria = subsJson.criteria
		set message.resourceType = resourceType
		
		// serialize Subscription to message.subscriptionStream
		do subsJson.%ToJSON(message.subscriptionStream)
		
		// loop over matching resources
		for i = 1:1:$listLength(rsrcIdList)
		{
			#dim resourceId As %String = $listGet(rsrcIdList, i)
			#dim httpMethod As %String = $get(..currentResourcesToBeProcessed(resourceType, resourceId))
			#dim rsrcJson As %DynamicObject = $get(..currentResourcesToBeProcessed(resourceType, resourceId, "json"))
			
			// skip incomplete resources
			if '$isObject(rsrcJson) continue
			
			do message.matchingResources.Insert("")
			#dim item As isc.ateam.fsub.msg.OneErrorSerial = message.matchingResources.GetAt(message.matchingResources.Count())
			
			set item.resourceId = resourceId
			set item.httpMethod = httpMethod
			set item.resourceType = resourceType
			do rsrcJson.%ToJSON(item.resourceStream)
			
		} // for loop over matching resources

		
		#dim description As %String = "Subscription id=" _ subsId _ "; resourceType=" _ resourceType
		do ..sendToProductionAsync(message, description)
		
	} //for loop over Subscriptions in matchesArray
}

Method logError(resourceType As %String, rsrc As %DynamicObject = "", httpMethod As %String, rsrcId As %String, exception As %Exception.AbstractException) As isc.ateam.fsub.msg.OneErrorSerial [ Private ]
{
	#dim newItem As isc.ateam.fsub.msg.OneErrorSerial = ""
	
	try
	{
		do ..currentListOfErrors.Insert("")
		set newItem = ..currentListOfErrors.GetAt(..currentListOfErrors.Count())
		
		set newItem.resourceType = resourceType
		set newItem.resourceId = rsrcId
		if $isObject(rsrc) do rsrc.%ToJSON(newItem.resourceStream)
		set newItem.httpMethod = httpMethod
		set newItem.status = exception.AsStatus()
		set newItem.errorCodes = $System.Status.GetErrorCodes(newItem.status)
		set newItem.errorText = $System.Status.GetErrorText(newItem.status)

		#dim stack
		do exception.StackAsArray(.stack)
		if $data(stack) && (+$get(stack) > 1)
		{
			#dim stackList As %List = ""
			for i = +$get(stack):-1:2
			{
				set stackList = stackList _ $lb($get(stack(i, "PLACE")))
			}

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

/// Retrieve and cache criteria/end/... values of all active non-deleted non-expired Subscription resources into @..subscriptionsGlobal
ClassMethod initializeSubscriptionCache(globalName As %String, interactions As HS.FHIRServer.Storage.Json.Interactions, strategy As HS.FHIRServer.API.InteractionsStrategy)
{
	#dim lock As %String = globalName
	
	lock +@lock:..#lockTIMEOUT
	if '$TEST $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot acquire lock: " _ globalName))
	
	try
	{
		$$$FSLog("About to (re-)initialize Subscription cache in " _ globalName)
		
		kill @globalName
		
		#dim susbcrSearchTable As %String = strategy.GetSearchTable("Subscription")
		#dim rsrcClass As %String = strategy.GetResourceClass("Subscription")
		
		//kill sqlParams
		//set sqlParams($i(sqlParams)) = "off"

		#dim cnt As %Integer = 0
		#dim sql As %String = ""
		set sql = "SELECT t0._id, t0._lastUpdated, t0.criteria FROM " _ susbcrSearchTable _ " t0 " _ 
							" WHERE %NOINDEX t0.status != 'off' AND t0.criteria IS NOT NULL " _
							" ORDER BY 1 ASC "

		#dim sqlResultSet As %SQL.StatementResult = ##class(HS.FHIRServer.Util.RunSQLQuery).runQuery(sql)  // runQuery(sql, .sqlParams)
		while (sqlResultSet.%Next())
		{
			#dim id As %Integer = +sqlResultSet.%GetData(1)
			//#dim lastUpdated As %String = sqlResultSet.%GetData(2)
			#dim criteria As %String = sqlResultSet.%GetData(3)
			
			// skip deleted Subscriptions
			if $classmethod(rsrcClass, "KeyIdxExists", "Subscription/" _ id, .tempId)
					&& ($classmethod(rsrcClass, "DeletedGetStored", tempId) '= $$$NO)
			{
				continue
			}
			
			#dim subs As %DynamicObject = interactions.Read("Subscription", id)
			
			// skip expired Subscriptions
			#dim endTS As %TimeStamp = ""
			if (subs.end '= "")
			{
				set endTS = ##class(%TimeStamp).XSDToLogical(subs.end)  // UTC
				if (endTS '= "") && (0 <= $System.SQL.DATEDIFF("ms", endTS, $zdatetime($ztimestamp, 3, 1, 3)))
				{
					$$$FSLog("Skipping expired Subscription; end=" _ subs.end _ ", id=" _ id)
					continue
				}
			}

			#dim resourceType As %String = $piece(criteria, "?", 1)
			#dim queryString As %String = $piece(criteria, "?", 2, *)
			set @globalName@(resourceType, id) = queryString
			if (endTS '= "") set @globalName@(resourceType, id, "end") = endTS
			set cnt = cnt + 1
			
			if (queryString '= "")
			{
				// parse criteria
				#dim params As HS.FHIRServer.API.Data.QueryParameters = ##class(HS.FHIRServer.API.Data.QueryParameters).CreateFromQueryString(
						queryString, 
						strategy.schema, 
						resourceType)
					
				// search for _id just in case
				for i = 1:1:params.Count()
				{
					#dim item As HS.FHIRServer.API.SearchQueryParameter = params.GetAt(i)
					if (item.name = "_id")
					{
						set @globalName@(resourceType, id, "_id") = item.value
						quit
					}
				} // for
			}
			
		} // while
		
		if (cnt > 0) set @globalName = cnt
	}
	catch ex
	{
		lock -@lock
		throw ex
	}
	
	lock -@lock
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

