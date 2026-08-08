extends Object

const STR_DOUBLE_QUOTE: = "\""


## Checks if the ASC has the given tag or any of its children.
static func has_tag(tags: Array[StringName], tag_query: StringName, exact: = false) -> bool:
	if tag_query in tags:
		return true
	if exact:
		return false

	var tag_query_str = String(tag_query)
	for tag in tags:
		var tag_str = String(tag)
		if tag_str.begins_with(tag_query_str + "."):
			return true

	return false


## Returns true if the ASC has at least one of the tags in the array.
static func has_any_tags(tags: Array[StringName], tag_queries: Array[StringName], exact: = false) -> bool:
	for tag_query in tag_queries:
		if has_tag(tags, tag_query, exact):
			return true
	return false


## Returns true only if the ASC has every tag in the array.
static func has_all_tags(tags: Array[StringName], tag_queries: Array[StringName], exact: = false) -> bool:
	if tag_queries.is_empty():
		return false
	for tag_query in tag_queries:
		if not has_tag(tags, tag_query, exact):
			return false
	return true


## Returns if the supplied tag is considered "strict".
static func is_strict(tag_query: StringName) -> bool:
	return \
		tag_query.begins_with(STR_DOUBLE_QUOTE) \
		and tag_query.ends_with(STR_DOUBLE_QUOTE)


## Returns a strict representation of the tag.
static func to_strict(tag_query: StringName) -> StringName:
	if is_strict(tag_query):
		return tag_query
	var test: = StringName(
		STR_DOUBLE_QUOTE \
		+ tag_query \
		+ STR_DOUBLE_QUOTE
	)
	return test


## Returns a strict representation of the tag.
static func to_lax(tag_query: StringName) -> StringName:
	if not is_strict(tag_query):
		return tag_query
	return StringName(
		tag_query \
			.trim_prefix(STR_DOUBLE_QUOTE) \
			.trim_suffix(STR_DOUBLE_QUOTE)
	)

