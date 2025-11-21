#!/bin/bash

# Normalize transcript JSONL to simple JSON structure for JavaScript rendering
# Input: transcript.jsonl file
# Output: Normalized JSON with flat array of elements

FILE="$1"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "Error: Transcript file not found: $FILE" >&2
    exit 1
fi

# Build lookups first
SLASH_EXPANSIONS=$(jq -s '[.[] | select(.type == "user" and .isMeta == true and (.message.content | type) == "array")] | map({(.parentUuid): .message.content[0].text}) | add // {}' "$FILE")

TEMP_RESULTS=$(mktemp)
jq -s '[.[] | select(.type == "user" and .toolUseResult != null)] | map({(.message.content[0].tool_use_id): {content: (if (.message.content[0].content | type) == "string" then .message.content[0].content elif (.message.content[0].content | type) == "array" then ([.message.content[0].content[] | if .type == "text" then .text else empty end] | join("\n")) else "" end), is_error: (.message.content[0].is_error // false)}}) | add // {}' "$FILE" > "$TEMP_RESULTS"

# Transform to normalized structure
jq -s --argjson expansions "$SLASH_EXPANSIONS" --slurpfile results_file "$TEMP_RESULTS" '
$results_file[0] as $results |

# Extract session metadata from first non-null occurrence
([.[] | .cwd // empty] | .[0] // "") as $cwd |

# Function to make file paths relative to project root
def make_relative_path(path; root):
  if (path | startswith(root + "/")) then
    path | sub("^" + root + "/"; "")
  else
    path
  end;

{
  session: {
    id: ([.[] | .sessionId // empty] | .[0] // "unknown"),
    short_id: (([.[] | .sessionId // empty] | .[0] // "unknown") | .[0:8]),
    started_at: ([.[] | .timestamp // empty] | .[0] // ""),
    branch: ([.[] | .gitBranch // empty] | .[0] // "unknown"),
    cwd: $cwd,
    stats: {
      total_messages: ([.[] | select(.type == "user" or .type == "assistant")] | length),
      user_messages: ([.[] | select(.type == "user")] | length),
      assistant_messages: ([.[] | select(.type == "assistant")] | length),
      input_tokens: ([.[] | select(.message.usage.input_tokens != null) | .message.usage.input_tokens] | add // 0),
      output_tokens: ([.[] | select(.message.usage.output_tokens != null) | .message.usage.output_tokens] | add // 0),
      cache_tokens: ([.[] | select(.message.usage.cache_read_input_tokens != null) | .message.usage.cache_read_input_tokens] | add // 0)
    }
  },
  elements: [
    .[] | select(.type == "user" or .type == "assistant") |

    # Slash command → tool element
    if .type == "user" and (.message.content | type) == "string" and (.message.content | test("<command-message>")) then
      (.message.content | capture("<command-name>(?<cmd>[^<]+)</command-name>")) as $cmd |
      (.message.content | capture("<command-args>(?<args>[^<]*)</command-args>") // {args: ""}) as $args |
      ($expansions[.uuid] // "") as $expansion |
      {
        type: "tool",
        role: "user",
        tool_name: "SlashCommand",
        timestamp: .timestamp,
        display: $cmd.cmd,
        input: ($cmd.cmd + (if $args.args and ($args.args | length) > 0 then " " + $args.args else "" end)),
        result: ($expansion | if (. | length) > 5000 then (.[0:5000] + "\n\n[... truncated " + ((. | length) - 5000 | tostring) + " chars]") else . end),
        is_error: false
      }

    # Skip meta/bash I/O
    elif .type == "user" and (.isMeta == true or ((.message.content | type) == "string" and (.message.content | test("<bash-")))) then
      empty

    # Regular user message
    elif .type == "user" then
      (if (.message.content | type) == "string" then .message.content else ((.message.content[] | select(.type == "text") | .text) // "") end) as $text |
      if $text and ($text | length) > 0 then
        {
          type: "message",
          role: "user",
          timestamp: .timestamp,
          text: $text
        }
      else empty end

    # Assistant message (split into message + tools)
    elif .type == "assistant" then
      ((.message.content[] | select(.type == "text") | .text) // "") as $text |
      [.message.content[] | select(.type == "tool_use")] as $tools |

      # Emit message if has text
      (if $text and ($text | length) > 0 then
        {
          type: "message",
          role: "assistant",
          timestamp: .timestamp,
          text: $text
        }
      else empty end),

      # Emit each tool separately
      ($tools[] |
        . as $tool |
        ($results[$tool.id] // {content: "", is_error: false}) as $result |
        {
          type: "tool",
          role: "assistant",
          tool_name: $tool.name,
          timestamp: .timestamp,
          display: (
            if $tool.input.description and ($tool.input.description | length) > 0 then
              $tool.input.description
            elif $tool.input.file_path then
              make_relative_path($tool.input.file_path; $cwd)
            elif $tool.input.url then
              $tool.input.url
            else
              ""
            end
          ),
          input: (
            if $tool.input.command then $tool.input.command
            elif $tool.input.file_path then $tool.input.file_path
            elif $tool.input.pattern then $tool.input.pattern
            elif $tool.input.url then $tool.input.url
            elif $tool.input.code then $tool.input.code
            else ($tool.input | tostring)
            end
          ),
          result: (($result.content // "") | if (. | length) > 5000 then (.[0:5000] + "\n\n[... truncated " + ((. | length) - 5000 | tostring) + " chars]") else . end),
          is_error: ($result.is_error // false)
        }
      )

    else empty end
  ]
}
' "$FILE"

# Cleanup
rm -f "$TEMP_RESULTS"
