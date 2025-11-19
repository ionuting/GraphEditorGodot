extends Node

## UUIDGenerator - Generates RFC 4122 compliant UUIDs (version 4)
## Provides unique identifiers for nodes and relationships in the graph database

# Static UUID generation - can be called without instantiation
static func generate_uuid() -> String:
	var uuid = ""
	var random = RandomNumberGenerator.new()
	random.randomize()
	
	# Generate 32 hex characters (128 bits)
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			uuid += "-"
		
		if i == 12:
			# Version 4 UUID - set version bits to 0100
			uuid += "4"
		elif i == 16:
			# Variant bits - set to 10xx (RFC 4122)
			var variant = random.randi_range(8, 11)
			uuid += "%x" % variant
		else:
			uuid += "%x" % random.randi_range(0, 15)
	
	return uuid

# Validate UUID format (basic check)
static func is_valid_uuid(uuid: String) -> bool:
	if uuid.length() != 36:
		return false
	
	# Check format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
	var parts = uuid.split("-")
	if parts.size() != 5:
		return false
	
	if parts[0].length() != 8 or parts[1].length() != 4 or parts[2].length() != 4 or parts[3].length() != 4 or parts[4].length() != 12:
		return false
	
	# Check version (should be 4)
	if parts[2][0] != "4":
		return false
	
	return true

# Generate a short UUID (first 8 characters) for display purposes
static func generate_short_uuid() -> String:
	return generate_uuid().substr(0, 8)