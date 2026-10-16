def normalize:
  gsub("\\s+"; " ") | ltrimstr(" ") | rtrimstr(" ");

def schema_paths($path; $allowed):
  if type != "object" then empty
  else
    (
      if has("description") then
        if (.description | type) != "string" then
          error("schema description must be a string")
        elif $allowed[(.description | normalize)] then
          $path + ["description"]
        else empty end
      else empty end
    ),
    (
      to_entries[]
      | .key as $key
      | .value
      | if (["properties", "patternProperties", "definitions", "$defs", "dependencies", "dependentSchemas"] | index($key)) != null then
          if type != "object" then error("schema \($key) must be a mapping")
          else
            to_entries[]
            | .key as $child
            | .value
            | schema_paths($path + [$key, $child]; $allowed)
          end
        elif (["items", "additionalItems", "additionalProperties", "not", "allOf", "anyOf", "oneOf", "contains", "if", "then", "else", "propertyNames"] | index($key)) != null then
          if type == "array" then
            to_entries[]
            | .key as $index
            | .value
            | schema_paths($path + [$key, $index]; $allowed)
          else schema_paths($path + [$key]; $allowed)
          end
        else empty end
    )
  end;

if ($allowlist | length) != 1
  or ($allowlist[0] | type) != "array"
  or ($allowlist[0] | length) == 0
  or any($allowlist[0][]; type != "string")
then error("description allowlist must be a nonempty array of strings")
else . end
| if any($allowlist[0][]; . == "" or . != normalize)
    or ($allowlist[0] | unique | length) != ($allowlist[0] | length)
  then error("allowlisted descriptions must be unique, nonempty, and whitespace-normalized")
  else . end
| (reduce $allowlist[0][] as $text ({}; .[$text] = true)) as $allowed
| [
    .[]
    | if .kind == "CustomResourceDefinition" then
        if (.spec.versions | type) != "array" then error("CRD spec.versions must be a sequence")
        else [
          .spec.versions
          | to_entries[]
          | .key as $version
          | .value.schema.openAPIV3Schema
          | if type != "object" then error("CRD version must contain schema.openAPIV3Schema")
            else schema_paths(["spec", "versions", $version, "schema", "openAPIV3Schema"]; $allowed)
            end
        ] end
      else [] end
  ]
