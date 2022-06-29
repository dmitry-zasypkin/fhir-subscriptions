/// Functions that can be used within business rules.
Class isc.ateam.fsub.FSUBFunctionSet Extends Ens.Rule.FunctionSet
{

ClassMethod FromJSON(stream As %Stream.Object) As %DynamicObject
{
	if '$isObject(stream) || (stream.Size = 0) quit ""
	quit ##class(%DynamicObject).%FromJSON(stream)
}

ClassMethod ArrayFromJSON(listOfStreams As %ListOfObjects) As %DynamicArray
{
	if '$isObject(listOfStreams) || (listOfStreams.Count() = 0) quit []
	
	#dim result As %DynamicArray = []
	for i = 1:1:listOfStreams.Count()
	{
		#dim stream As %Stream.Object = listOfStreams.GetAt(i)
		#dim json As %DynamicObject = $case(stream.Size, 0:{}, :##class(%DynamicObject).%FromJSON(stream))
		do result.%Push(json)
	}
	
	quit result
}

ClassMethod GetEntry(array As %DynamicArray, n As %Integer) As %DynamicObject
{
	quit array.%Get(n)
}

/// Return just one result, either JSON object/array or a single value. 
/// resourceType argument is used to distinguish arrays from non-arrays.
ClassMethod GetFHIRPathOne(json As %DynamicObject, path As %String, resourceType As %String, mdSetKey As %String = "HL7v40") As %String(MAXLEN="") [ SqlName = GetFHIRPathOne, SqlProc ]
{
	if (json = "") quit ""
	if '$isObject(json) set json = {}.%FromJSON(json)
	
	#dim fpAPI As HS.FHIRPath.API = ##class(HS.FHIRPath.API).getInstance(mdSetKey)
	#dim node As HS.FHIRPath.Node = fpAPI.parse(path)

	#dim array As %DynamicArray = fpAPI.evaluateToJson(json, node)
	if (array = "") quit ""

	do fpAPI.getPathAndType(resourceType, node, .contextPath, .fhirType)
	
	#dim result = array
	if (($get(fhirType("ar")) = $$$NO) || ($extract($zstrip(path, ">W"), *) = "]"))
	{
		set result = array.%Get(0)
	}
	
	quit $case($isObject(result), $$$YES:/*result.%ClassName(1) _ ":" _ */result.%ToJSON(), :result)
}

}

