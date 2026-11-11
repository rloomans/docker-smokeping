walk(
  if type == "object" and (.properties | type) == "object" then
    .properties |= with_entries(select(.key != "security-severity" or (.value != null and .value != "null")))
  else
    .
  end
)
# Snyk can suggest an unavailable upgrade as boolean false; discard that fix, not the result.
| .runs[]?.results[]? |= (
    if (.fixes | type) == "array" then
      .fixes |= map(select(
        any(.artifactChanges[]?.replacements[]?.insertedContent?;
            type == "object" and has("text") and (.text | type != "string")) | not
      ))
      | if .fixes == [] then del(.fixes) else . end
    else
      .
    end
  )
