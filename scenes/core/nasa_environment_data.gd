class_name NasaEnvironmentData
extends RefCounted
## Adapter boundary for future NASA datasets. Raw observations never directly
## overwrite gameplay balance values; adapters normalize them into scenarios.

const SCHEMA_VERSION := 1
const REQUIRED_PROVENANCE := ["dataset_id", "title", "provider", "version", "retrieved_utc", "citation_url"]

## Validate normalized observations before they enter the simulation.
static func validate_bundle(bundle: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if int(bundle.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("Unsupported adapter schema version")
	var provenance: Dictionary = bundle.get("provenance", {})
	for field in REQUIRED_PROVENANCE:
		if String(provenance.get(field, "")).is_empty():
			errors.append("Missing provenance: %s" % field)
	var location: Dictionary = bundle.get("location", {})
	if not location.has("lat") or not location.has("lon"):
		errors.append("Missing location coordinates")
	var variables: Dictionary = bundle.get("variables", {})
	var sunlight: Variant = variables.get("sunlight", [])
	if not sunlight is Array:
		errors.append("Sunlight must be a sample array")
		return {"valid": false, "errors": errors}
	if sunlight.is_empty():
		errors.append("Missing normalized sunlight sequence")
	for item in sunlight:
		if not item is Dictionary or not item.has("value") or not item.has("unit") or not item.has("timestamp"):
			errors.append("Sunlight samples require value, unit, and timestamp")
			break
		if String(item.unit) != "fraction" or float(item.value) < 0.0 or float(item.value) > 1.0:
			errors.append("Normalized sunlight must be a 0–1 fraction")
			break
	return {"valid": errors.is_empty(), "errors": errors}


## Displayable source and limitation metadata for the mission info panel.
static func attribution(bundle: Dictionary) -> Dictionary:
	var p: Dictionary = bundle.get("provenance", {})
	return {"title": p.get("title", "Scenario data"), "provider": p.get("provider", "Unspecified"),
		"version": p.get("version", "Unspecified"), "citation_url": p.get("citation_url", ""),
		"retrieved_utc": p.get("retrieved_utc", ""), "is_live": bool(p.get("is_live", false)),
		"limitations": p.get("limitations", "")}
