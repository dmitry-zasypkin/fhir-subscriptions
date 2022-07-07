/// Validates status and criteria elements of Subscription resources
Class isc.ateam.fsub.SubscriptionValidator Extends HS.FHIRServer.Util.ResourceValidator
{

/// @API
/// ValidateResource validates a FHIR Resource.  If a validation error is found, a
/// compound %Status is thrown in a StatusException.  The compound %Status starts with a
/// $$$ValidationFailure code, followed by additional %Status objects for each detected
/// validation error.
/// Inputs:
/// <li>pJsonResource           : (required) %DynamicObject representation of the FHIR resource.
/// <li>Throws					: A StatusException containing a compound %Status representing all
///                             : validation errors.
Method ValidateResource(pResourceObject As %DynamicObject)
{
	do ##super(pResourceObject)
	
	// we only need to validate Subscription resources
	if (pResourceObject.resourceType '= "Subscription") quit

	
	#dim sc As %Status = $$$OK
	try
	{
		// require Subscription.status="requested" as per the R4 spec (?)
		//   see https://www.hl7.org/fhir/r4/valueset-subscription-status.html#expansion
		//   and https://www.hl7.org/fhir/r4/subscription.html#errors
		if (pResourceObject.status '= "requested")
		{
			set sc = $$$ERROR($$$GeneralError, "Only 'requested' status is allowed")
			quit
		}
		
		// validate Subscription.criteria
		set sc = ..validateSubscriptionCriteria(pResourceObject.criteria, ..metaAPI)
	}
	catch ex
	{
		set sc = ex.AsStatus()
	}
	
	if $$$ISERR(sc)
	{
		#dim rootsc As %Status = $$$ERROR($$$HSFHIRErrValidationFailure, $$$OutcomeIs(400, "error", "invalid"))
		$$$FHIRAddError(rootsc, sc)
		$$$ThrowStatus(rootsc)
	}
}

/// Validates "criteria" elements of Subscription resources.
/// Note that "criteria" is a required element as per R4 spec.
ClassMethod validateSubscriptionCriteria(criteria As %String, schema As HS.FHIRServer.Schema) As %Status
{
	#dim resourceType As %String = $piece(criteria, "?", 1)
	#dim queryString As %String = $piece(criteria, "?", 2, *)

	// 1. validate resource type part of criteria
	if (resourceType = "") || 'schema.IsValidResourceType(resourceType)
	{
		quit $$$ERROR($$$GeneralError, "Unrecognized resource type specified in Subscription.criteria: " _ resourceType)
	}

	// 2. validate query string part of criteria if any
	if (queryString = "") quit $$$OK

	// parse query string
	#dim params As HS.FHIRServer.API.Data.QueryParameters = ##class(HS.FHIRServer.API.Data.QueryParameters).CreateFromQueryString(
			queryString, 
			schema, 
			resourceType)
	
	quit params.status
}

}

